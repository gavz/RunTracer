#Prospector - Ruby tools for distributed tracing and analysis

#Prerequisites:

##Server Side ( tested on linux )

###Ruby Stuff

* Access to Tokyo Cabinet files
		gem install oklahoma_mixer

* Fast serialization
		gem install msgpack

* Access to beanstalkd
		gem install beanstalk_client

* Option parsing
		gem install trollop

###Infrastructure

Please google for latest packages and download sites.

* Tokyo Cabinet
* Beanstalkd

##Client Side ( tested on XPSP3 )

###Ruby Stuff

* Fast serialization
		gem install msgpack

* Access to beanstalkd
		gem install beanstalk_client

* Option parsing
		gem install trollop

* Win32 stuff - may need DevKit, check google
		gem install win32-process --platform=ruby
		gem install sys-proctable --platform=x86-mswin32
		gem install win32-api --platform=ruby

##Running:

In general, start beanstalkd like:
		beanstalkd -z 30000000 -d

To allow 30MB work items to be pushed

Then, bring up the *_worker.rb components, in any order. They all support --help.

- trace_worker.rb - Win32 tracer
- trace_insert_worker.rb - Inserts files and stores traces, manages queue size
- iterative_reduction_worker.rb - Maintains a pre-reduced set of filenames
- trace_compression_worker.rb - Runs the lookup DB for edge string<->DB Index mappings, compresses traces very small

When you're done, you can extra compress the reduced set with greedy_reducer.rb, if you want.
