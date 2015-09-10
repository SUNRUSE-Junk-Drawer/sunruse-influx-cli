# Takes:
#	A JSON object containing the configuration entered, being:
#		platform: String specifying the platform to compile for, of:
#			"javascript"
#		mode: String specifying the stage during compilation to write to 
#			standard output, of:
#			"inputJson": JSON for the value object to be given as input.
#			"fileJson": JSON for the dictionary of loaded files.
#			"tokenizedJson": JSON for the tokenized source code.
#			"valueJson": JSON for the value object generated after compilation.
#			"nativeCode": The final generated native code.
#		filenames: Array of strings specifying paths to source code to compile.
#		functionName: The name of the function to compile.
#		input: Array of strings describing parameters to provide as input to
#			the function being compiled.  Handled by parameterBuilder.
#		tabSize: The third argument of JSON.stringify; zero is no newlines,
#			numbers specify a number of spaces to use as tabs, strings specify
#			a string to use as tabs.
module.exports = (configuration) ->
	if configuration.mode is "assertionResults" and not configuration.runAssertions
		module.exports.processStderr.write "Cannot output assertion results when assertions are disabled using -a or --run-assertions"
		module.exports.processExit 1
	else
		platform = (module.exports.require configuration.platform)()
		input = undefined
		try
			input = module.exports.parameterBuilder platform, configuration.input
		catch error
			module.exports.processStderr.write switch error.reason
				when "parameterDefinedMultipleTimes" then "Error building input from parameters; two or more parameters define the same chain \"" + (error.chain.join ".") + "\".  The error was found while building parameter \"" + error.parameter + "\"."
				when "primitiveTypeOrLiteralUnrecognized" then "Error building input from parameters; an unrecognized primitive type name or literal \"" + error.type + "\" was found following the chain \"" + (error.chain.join ".") + "\"."
				else "Unexpected error while building input from parameters:"
			if error.reason is undefined
				throw error
			else
				module.exports.processExit 1			
			
		if input
			if configuration.mode is "inputJson"
				module.exports.processStdout.write module.exports.jsonStringify input, null, configuration.tabSize
			else
				uniqueNames = {}
				for name in configuration.filenames
					uniqueNames[name] = null
					
				files = {}
				for name in Object.keys uniqueNames
					do (name) ->
						module.exports.fsReadFile name, "utf8", (err, content) ->
							if err
								module.exports.processStderr.write "Failed to read file \"" + name + "\":"
								module.exports.processStderr.write err
								module.exports.processExit 1
								files = null
							else if files
								files[name] = content
								if (Object.keys uniqueNames).length is (Object.keys files).length
									if configuration.mode is "fileJson"
										module.exports.processStdout.write module.exports.jsonStringify files, null, configuration.tabSize
									else
										tokenized = undefined
										try
											tokenized = module.exports.toolchain.tokenizer files
										catch error
											if error.reason and error.line
												module.exports.processStderr.write "Failed to tokenize the source code; encountered \"" + error.reason + "\" in file \"" + error.line.filename + "\" on line " + error.line.line + " between columns " + error.line.columns.from + " and " + error.line.columns.to + "."
												module.exports.processExit 1
											else
												module.exports.processStderr.write "Unexpected error while tokenizing the source code:"
												throw error						
										if tokenized
											if configuration.mode is "tokenizedJson"
												module.exports.processStdout.write module.exports.jsonStringify tokenized, null, configuration.tabSize
											else
												platform.functions = tokenized
												assertionsFailed = false
												if configuration.runAssertions
													assertions = module.exports.toolchain.runAssertions platform
													grouped = {}
													for assertion in assertions
														filename = assertion.assertion.line.filename
														if not grouped[filename] then grouped[filename] = []
														grouped[filename].push assertion
														if assertion.resultType isnt "successful" then assertionsFailed = true
													if configuration.mode is "assertionResults" or assertionsFailed
														target = if configuration.mode is "assertionResults" then module.exports.processStdout else module.exports.processStderr
														compose = ""
														for filename of grouped
															compose += filename + "\n"
															grouping = grouped[filename]
															grouping.sort (a, b) -> a.assertion.line.line - b.assertion.line.line
															for assertion in grouping
																compose += "\tLine " + assertion.assertion.line.line + " - "
																compose += switch assertion.resultType
																		when "successful" then "Successful"
																		when "failedToCompile" then "Failed to compile"
																		when "didNotReturnPrimitiveConstant" then "Did not return a primitive constant"
																		when "primitiveTypeNotAssertable" then "Returned non-assertable primitive type \"" + assertion.output.primitive.type + "\": " + (JSON.stringify assertion.output.primitive.value)
																		when "primitiveValueIncorrect" then "Returned unexpected primitive value of type \"" + assertion.output.primitive.type + "\": " + (JSON.stringify assertion.output.primitive.value) + " whereas " + (JSON.stringify platform.primitives[assertion.output.primitive.type].assertionPass) + " was expected"
																compose += "\n"
														if compose then compose = compose.slice 0, -1
														target.write compose
														if configuration.mode isnt "assertionResults" then module.exports.processExit 1
												if not assertionsFailed and configuration.mode isnt "assertionResults"
													output = undefined
													errorred = false
													logs = []
													try
														output = module.exports.toolchain.findFunction platform, input, configuration.functionName, logs, "", {}
													catch error
														module.exports.processStderr.write "Unexpected error while compiling the source code:"
														throw error
													if not output and not errorred
														module.exports.processStderr.write "Failed to compile the input specified as parameters for the function name specified.\nThe log of the pattern matches attempted follows:\n" + logs.join "\n"
														module.exports.processExit 1
													if output
														switch configuration.mode 
															when "valueJson"
																module.exports.processStdout.write module.exports.jsonStringify output, null, configuration.tabSize
															when "patternMatchingLog"
																module.exports.processStdout.write logs.join "\n"														
															else
																compiled = undefined
																try
																	compiled = platform.compile platform, input, output
																catch error
																	module.exports.processStderr.write "Unexpected error while generating native code:"
																	throw error									
																if compiled
																	module.exports.processStdout.write compiled
module.exports.fsReadFile = (require "fs").readFile
module.exports.parameterBuilder = require "./parameterBuilder"

module.exports.processExit = process.exit
module.exports.processStderr = process.stderr
module.exports.processStdout = process.stdout
module.exports.jsonStringify = JSON.stringify
module.exports.toolchain = require "sunruse-influx-toolchain"
module.exports.require = require