A command-line tool to compile SUNRUSE.influx programs.

# Usage:

	sunruse-influx -p sunruse-influx-platforms-javascript -f example.influx -i x>5.3
	
    sunruse-influx -p sunruse-influx-platforms-javascript -m nativeCode -f example.influx library.influx -n main -i x>5.3 y>float -t 4 -a true

## Parameters

### -p, --platform
The name of a NPM package to use as a platform.  This is usually of the form sunruse-influx-platforms-*, such as sunruse-influx-platforms-javascript.

### -m, --mode (defaults to nativeCode)
Defines what is written to standard output on success.  Of the following values:

* inputJson
* fileJson
* tokenizedJson
* assertionResults
* valueJson
* patternMatchingLog
* nativeCode (default)

### -f --filenames
The paths to one or more files to compile.

### -n --function-name (defaults to main)
The name of the function to compile.

### -i --input
One or more parameters to provide to the function being compiled.  These can be of the form:
* 4.5, -7, true, or other primitive constants.  (platform dependent)
* int, float, bool, or other primitive type names.  (platform dependent)
* the>path>to>a>nested>property>then>either>of>the>above

### -t --tab-size (defaults to zero)
The number of spaces or string to use as tabs in JSON output.  When zero, no newlines are inserted.

### -a --run-assertions (defaults to true)
When true, every assertion in the files being compiled is ran before compiling the function specified.  If any fail, compilation is aborted.