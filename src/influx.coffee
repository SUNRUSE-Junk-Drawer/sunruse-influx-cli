yargs = require "yargs"

configuration = yargs
	.alias "p", "platform"
	.describe "p", "The name of a SUNRUSE.influx platform package from NPM to build for such as sunruse-influx-platforms-javascript"
	.string "p"
	.require "p"
	
	.alias "m", "mode"
	.describe "m", "The data to output on success"
	.choices "m", ["inputJson", "fileJson", "tokenizedJson", "assertionResults", "valueJson", "patternMatchingLog", "nativeCode"]
	.default "m", "nativeCode"	
	.string "m"
	
	.alias "f", "filenames"
	.describe "f", "The paths to one or more files to compile"
	.array "f"
	.string "f"
	.require "f"
	
	.alias "n", "function-name"
	.describe "n", "The name of a function to compile"
	.string "n"
	.default "n", "main"
	
	.alias "i", "input"
	.describe "i", "One or more parameters to include, in the format propertyName>propertyName>primitiveTypeName, or just primitiveTypeName"
	.array "i"	
	.string "i"
	
	.alias "t", "tab-size"
	.default "t", 0
	.describe "t", "The number of spaces or string to use as tabs.  When zero, no newlines are inserted"
	
	.alias "a", "run-assertions"
	.default "a", true
	.boolean "a"
	.describe "a", "When true, all assertions in the specified files are tested before attempting to compile the output"
	
	.argv

(require "./compiler") configuration