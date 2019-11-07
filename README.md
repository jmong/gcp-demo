# gcp-demo

Learn Google Cloud Platform (GCP) concepts through demos.

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

## License

See [LICENSE](LICENSE)

## Author

Joe Mong
* Github - [https://github.com/jmong](https://github.com/jmong)
