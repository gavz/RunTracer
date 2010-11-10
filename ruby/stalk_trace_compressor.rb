# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2010.
# License: The MIT License
# (See README.TXT or http://www.opensource.org/licenses/mit-license.php for details.)

require 'rubygems'
require 'beanstalk-client'
require 'msgpack'
require 'tokyo_tyrant'
require File.dirname( __FILE__ ) + '/set_extensions'

class StalkTraceCompressor

    COMPONENT="StalkTraceCompressor"
    VERSION="1.0.0"

    attr_reader :processed_count

    def initialize( beanstalk_servers, beanstalk_port, tt_server, tt_port, debug )
        @debug=debug
        servers=beanstalk_servers.map {|srv_str| "#{srv_str}:#{beanstalk_port}" }
        debug_info "Starting up, connecting to #{beanstalk_servers.join(' ')}"
        @lookup=TokyoTyrant::DB.new( tt_server, tt_port ) 
        debug_info "Opened remote database..."
        @stalk=Beanstalk::Pool.new servers
        @stalk.watch 'traced'
        @stalk.use 'compressed'
    end

    def close_database
        @lookup.close
    end

    def deflate( set )
        # No transactions here :( TT doesn't support them.
        begin
            collision_count=0
            set=set.map {|elem|
                unless (idx=@lookup[elem]) #already there
                    # this works even if there is no 'idx' record
                    idx=@lookup.addint 'idx', 1
                    # There is a race here, but if we lose then the only
                    # problem is incrementing the index for nothing (I hope)
                    begin
                        @lookup.putkeep elem,idx 
                    rescue TokyoTyrantErrorKeep
                        raise "Too racy" if (collision_count+=1) > 100
                        idx=@lookup[elem]
                    end
                end
                Integer( idx )
            }
        rescue
            debug_info "Too many collisions, calming the fuck down"
            sleep 60
            retry
        end
    end

    def debug_info( str )
        warn "#{COMPONENT}-#{VERSION}: #{str}" if @debug
    end

    def create_set( output )
        set=Set.new(output)
        raise "#{COMPONENT}-#{VERSION}: Set size should match array size from tracer" unless set.size==output.size
        debug_info "#{set.size} elements in Set"
        deflate set
    end

    def compress_trace( trace )
        set=create_set( trace )
        covered=set.size
        packed=set.pack
        debug_info "compressed trace with #{covered} blocks to #{"%.2f" % (packed.size/1024.0)}"
        [covered, packed]
    end

    def compress_next
        debug_info "getting next trace"
        job=@stalk.reserve # from 'traced' tube
        pdu=MessagePack.unpack( job.body )
        debug_info "compressing trace"
        covered, packed=compress_trace( pdu['trace_output'] ) 
        new_pdu={
            'covered'=>covered,
            'packed'=>packed, 
            'filename'=>pdu['filename'], 
            'result'=>pdu['result']
        }.to_msgpack
        @stalk.put new_pdu # to 'compressed' tube
        debug_info "Finished."
        job.delete
    rescue
        raise $!
    end

end
