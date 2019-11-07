# gcp-cli-sdk-playground

Learn Google Cloud Platform (GCP) concepts by following along in demos.

## Structure

Each directory contains script(s) that runs a demo of a GCP concept that you can follow along.
You simply execute the run script. It usually takes care of setting up and cleanly tearing down
GCP resources.

Output from each step in the demo will have one of the following labels.

#### [CHECK]

Validation step that checks certain dependencies are satisfied in order to fully run the script.

For example, if the script needs to execute `gcloud` commands, there could be a check that
the `gcloud` command actually exists.

#### [VERBOSE]

Outputs additional information.

For example, the following message lets you know which GCP project you are in.
```
[VERBOSE] PROJECT_ID = 12345
```

#### [INFO]

Outputs additional information, but usually related to the command that just got executed.

#### [RUN]

Executes a command. 

The output contains 4 parts:
* A brief description of what is executing
* The command that is executing (surrounded by '#')
* Output from the executing command
* Status message indicating whether the command executed successfully or not (following '..... ')

For example,
```
[RUN] Listing the current directory
# ls -1 #
mysubdir1
file1.txt
..... DONE
```

#### [DRYRUN]

Pretends executing a command. 

### Temp Directory

Some demos need to download or save temporary files, for example, cloning an external git project. However, these files should be isolated to this particular running instance of the demo. These files will be saved in its own unique sub-directory in the `tmp` directory. 

### Resource Directory

Some demos also need to access pre-defined files, for example, configuration files. These files will be located in its own unique sub-directory in the `res` directory.

### Log Directory

The entire output of the demo will also be saved into a log file. It will be located in the directory
called `log`.

## Author

Joe Mong

## License

Copyright 2019 Joe Mong

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
