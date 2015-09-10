describe "cli", ->
	describe "compiler", ->
		compiler = undefined
		beforeEach ->
			compiler = require "./compiler"
		describe "imports", ->
			it "JSON.stringify", ->
				expect(compiler.jsonStringify).toBe JSON.stringify
			it "fs.readFile", ->	
				expect(compiler.fsReadFile).toBe (require "fs").readFile
			it "toolchain", ->	
				expect(compiler.toolchain).toBe require "sunruse-influx-toolchain"				
			it "parameterBuilder", ->	
				expect(compiler.parameterBuilder).toBe require "./parameterBuilder"				
			it "process.stdout.write", ->	
				expect(compiler.processStdout).toBe process.stdout
			it "process.stderr.write", ->	
				expect(compiler.processStderr).toBe process.stderr												
			it "process.exit", ->	
				expect(compiler.processExit).toBe process.exit	
			# We can't check require was imported.
		describe "when called", ->
			platformInstance = _require = toolchain = fileContents = flushCallback = allCallbacksDone = configuration = platforms = jsonStringify = fsReadFile = parameterBuilder = processStdout = processStderr = processExit = null
			beforeEach ->
				fsReadFile = compiler.fsReadFile
				toolchain = compiler.toolchain
				_require = compiler.require
				parameterBuilder = compiler.parameterBuilder
				processStdout = compiler.processStdout
				processStderr = compiler.processStderr
				tokenize = compiler.tokenize
				processExit = compiler.processExit	
				platforms = compiler.platforms	
				jsonStringify = compiler.jsonStringify
			
				configuration =
					platform: "platformB"
					mode: "nativeCode"
					filenames: ["Test Filename A", "Test Filename B", "Test Filename A", "Test Filename C"]
					functionName: "Test FunctionName",
					input: "Test Configuration Parameters"
					tabSize: "Test Tab Size"			
				
				callbacks = []
				
				fileContents = 	
					"Test Filename A":
						error: null
						content: "Test File Content A"
					"Test Filename B":
						error: null
						content: "Test File Content B"
					"Test Filename C":
						error: null
						content: "Test File Content C"				
				
				flushCallback = ->
					expect(callbacks.length).not.toEqual 0
					first = callbacks.shift()
					result = fileContents[first.filename]
					expect(result).toBeDefined()
					first.callback result.error, result.content
				
				spyOn compiler, "fsReadFile"
					.and.callFake (filename, encoding, callback) ->
						expect(encoding).toEqual "utf8"
						callbacks.push
							filename: filename
							callback: callback
						
				platformInstance = 							
					primitives:
						"test primitive a":
							assertionPass: "platform b primitive a assertion pass"
						"test primitive b":
							assertionPass: "platform b primitive b assertion pass"
						"test primitive c":
							assertionPass: "platform b primitive c assertion pass"
					compile: (tokenized, input, output) ->
						expect(tokenized).toBe platformInstance
						expect(tokenized.functions).toEqual "Test Tokenized"
						expect(input).toEqual "Test Built Parameters"
						expect(output).toEqual "Test Compiled Output"
						"Test Native Code"
						
				compiler.toolchain = 
					findFunction: (tokenized, input, functionName, logs, logPrefix, cache) ->
						expect(tokenized).toBe platformInstance
						expect(tokenized.functions).toEqual "Test Tokenized"
						expect(input).toEqual "Test Built Parameters"
						expect(functionName).toEqual "Test FunctionName"
						expect(cache).toEqual {}
						if logs
							expect(logPrefix).toBe ""
							logs.push "Test Log A"
							logs.push "Test Log B"
							logs.push "Test Log C"
						"Test Compiled Output"
					tokenizer: (files) ->
						expect(files).toEqual
							"Test Filename A": "Test File Content A"
							"Test Filename B": "Test File Content B"
							"Test Filename C": "Test File Content C"	
						"Test Tokenized"
						
				spyOn compiler, "parameterBuilder"
					.and.callFake (tokenized, parameters) ->
						expect(tokenized).toBe platformInstance
						expect(parameters).toEqual configuration.input
						"Test Built Parameters"
				compiler.processStdout = 
					write: jasmine.createSpy()
				compiler.processStderr = 
					write: jasmine.createSpy()	
					
				spyOn compiler, "processExit"
					.and.stub()
				spyOn compiler, "jsonStringify"		
						
				compiler.require = (pkg) ->
					expect(pkg).toEqual "platformB"
					return -> platformInstance
											
			afterEach ->
				compiler.fsReadFile = fsReadFile
				compiler.toolchain = toolchain
				compiler.parameterBuilder = parameterBuilder
				compiler.processStdout = processStdout
				compiler.processStderr = processStderr
				compiler.processExit = processExit
				compiler.platforms = platforms
				compiler.jsonStringify = jsonStringify
				compiler.require = _require
				
			parameterTests = ->
				it "writes to stderr when a type resolution exception occurs while building an input from parameters", ->
					compiler.parameterBuilder.and.callFake ->
						throw
							reason: "primitiveTypeOrLiteralUnrecognized",
							type: "Test Type"
							chain: ["Test", "Error", "Chain"]
						
					compiler.processStderr.write.and.callFake (param) ->
						expect(compiler.processExit).not.toHaveBeenCalled()
					
					compiler configuration
					
					expect(compiler.processStderr.write.calls.allArgs()).toEqual [["Error building input from parameters; an unrecognized primitive type name or literal \"Test Type\" was found following the chain \"Test.Error.Chain\"."]]
					expect(compiler.processExit.calls.allArgs()).toEqual [[1]]
					expect(compiler.processStdout.write).not.toHaveBeenCalled()				
				
				it "writes to stderr when a conflict exception occurs while building an input from parameters", ->
					compiler.parameterBuilder.and.callFake ->
						throw
							reason: "parameterDefinedMultipleTimes",
							parameter: "Test Parameter"
							chain: ["Test", "Error", "Chain"]
						
					compiler.processStderr.write.and.callFake ->
						expect(compiler.processExit).not.toHaveBeenCalled()
					
					compiler configuration
					
					expect(compiler.processStderr.write.calls.allArgs()).toEqual [["Error building input from parameters; two or more parameters define the same chain \"Test.Error.Chain\".  The error was found while building parameter \"Test Parameter\"."]]
					expect(compiler.processExit.calls.allArgs()).toEqual [[1]]
					expect(compiler.processStdout.write).not.toHaveBeenCalled()
				
				it "writes to stderr and then rethrows when an unexpected exception occurs while building an input from parameters", ->
					compiler.parameterBuilder.and.callFake ->
						throw "Test Unexpected Exception"
						
					compiler.processStderr.write.and.callFake ->
						expect(compiler.processExit).not.toHaveBeenCalled()
					
					expect ->
							compiler configuration
						.toThrow "Test Unexpected Exception"
					
					expect(compiler.processStderr.write.calls.allArgs()).toEqual [["Unexpected error while building input from parameters:"]]
					expect(compiler.processExit).not.toHaveBeenCalled()
					expect(compiler.processStdout.write).not.toHaveBeenCalled()				
				
			fileTests = ->
				parameterTests()
				
				it "writes to stderr when a file fails to load", ->
					fileContents["Test Filename B"] = 
						error: "Test Error"
						content: null
						
					compiler.processStderr.write.and.callFake ->
						expect(compiler.processExit).not.toHaveBeenCalled()						

					compiler configuration
					
					flushCallback()
					flushCallback()
					flushCallback()
					
					expect(compiler.processExit.calls.allArgs()).toEqual [[1]]
					expect(compiler.processStdout.write).not.toHaveBeenCalled()
					expect(compiler.processStderr.write.calls.allArgs()).toEqual [["Failed to read file \"Test Filename B\":"], ["Test Error"]]								
				
			tokenizeTests = ->
				fileTests()
				
				it "writes to stderr when an expected exception occurs while tokenizing", ->
					compiler.toolchain.tokenizer = ->
						throw
							reason: "Test Reason"
							line:
								filename: "Test Filename"
								line: 12
								columns:
									from: 4
									to: 7
									
					compiler.processStderr.write.and.callFake ->
						expect(compiler.processExit).not.toHaveBeenCalled()									
						
					compiler configuration
					
					flushCallback()
					flushCallback()
					flushCallback()
					
					expect(compiler.processExit.calls.allArgs()).toEqual [[1]]
					expect(compiler.processStdout.write).not.toHaveBeenCalled()
					expect(compiler.processStderr.write.calls.allArgs()).toEqual [["Failed to tokenize the source code; encountered \"Test Reason\" in file \"Test Filename\" on line 12 between columns 4 and 7."]]					
				
				it "writes to stderr and then rethrows when an unexpected exception occurs while tokenizing", ->
					compiler.toolchain.tokenizer = ->
						throw "Test Unexpected Exception"
						
					compiler.processStderr.write.and.callFake ->
						expect(compiler.processExit).not.toHaveBeenCalled()						
						
					expect ->
							compiler configuration
							flushCallback()
							flushCallback()
							flushCallback()							
						.toThrow "Test Unexpected Exception"
					
					expect(compiler.processExit).not.toHaveBeenCalled()
					expect(compiler.processStdout.write).not.toHaveBeenCalled()
					expect(compiler.processStderr.write.calls.allArgs()).toEqual [["Unexpected error while tokenizing the source code:"]]					
				
			assertionTests = (next) ->
				tokenizeTests()
				
				describe "when assertions are disabled", ->
					it "does not check assertions passed", ->						
						compiler configuration
						
						flushCallback()
						flushCallback()
						flushCallback()
					next()
				
				describe "when assertions are enabled", ->
					beforeEach ->
						configuration.runAssertions = true
						
					describe "on success", ->
						beforeEach ->
							compiler.toolchain.runAssertions = (_tokenized) ->
								expect(_tokenized).toBe platformInstance
								expect(_tokenized.functions).toEqual "Test Tokenized"
								return [
										assertion:
											line:
												filename: "Test File A"
												line: 18
										resultType: "successful"
								]
						next()
						
					it "writes to stderr on failure", ->
						compiler.toolchain.runAssertions = (_tokenized) ->
							expect(_tokenized).toBe platformInstance
							expect(_tokenized.functions).toEqual "Test Tokenized"
							return [
									assertion:
										line:
											filename: "Test File A"
											line: 18
									resultType: "successful"
								,
									assertion:
										line:
											filename: "Test File A"
											line: 24
									resultType: "failedToCompile"
								,
									assertion:
										line:
											filename: "Test File B"
											line: 7
									resultType: "didNotReturnPrimitiveConstant"
									output:
										parameter:
											type: "a type"
								,
									assertion:
										line:
											filename: "Test File B"
											line: 9
									resultType: "primitiveTypeNotAssertable"
									output:
										primitive:
											type: "test primitive a"
											value: 123
								,
									assertion:
										line:
											filename: "Test File B"
											line: 11
									resultType: "primitiveValueIncorrect"								
									output:
										primitive:
											type: "test primitive b"
											value: [4, 8, 5]
							]
							
						compiler.processStderr.write.and.callFake ->
							expect(compiler.processExit).not.toHaveBeenCalled()
						
						compiler configuration
						
						flushCallback()
						flushCallback()
						flushCallback()
						
						expect(compiler.processExit.calls.allArgs()).toEqual [[1]]
						expect(compiler.processStdout.write).not.toHaveBeenCalled()
						expect(compiler.processStderr.write.calls.allArgs()).toEqual [["Test File A\n\tLine 18 - Successful\n\tLine 24 - Failed to compile\nTest File B\n\tLine 7 - Did not return a primitive constant\n\tLine 9 - Returned non-assertable primitive type \"test primitive a\": 123\n\tLine 11 - Returned unexpected primitive value of type \"test primitive b\": [4,8,5] whereas \"platform b primitive b assertion pass\" was expected"]]
				
			valueTests = ->
				assertionTests ->
					it "writes to stderr when the function fails to compile", ->
						compiler.toolchain.findFunction = (tokenized, input, functionName, logs, logPrefix) ->
							expect(tokenized).toBe platformInstance
							expect(tokenized.functions).toEqual "Test Tokenized"
								
							expect(input).toEqual "Test Built Parameters"
							expect(functionName).toEqual "Test FunctionName"
							if logs
								expect(logPrefix).toBe ""
								logs.push "Test Log A"
								logs.push "Test Log B"
								logs.push "Test Log C"
							null
							
						compiler.processStderr.write.and.callFake ->
							expect(compiler.processExit).not.toHaveBeenCalled()						
							
						compiler configuration
						
						flushCallback()
						flushCallback()
						flushCallback()
						
						expect(compiler.processExit.calls.allArgs()).toEqual [[1]]
						expect(compiler.processStdout.write).not.toHaveBeenCalled()
						expect(compiler.processStderr.write.calls.allArgs()).toEqual [["Failed to compile the input specified as parameters for the function name specified.\nThe log of the pattern matches attempted follows:\nTest Log A\nTest Log B\nTest Log C"]]
					
					it "writes to stderr and then rethrows when an unexpected exception occurs while compiling", ->
						compiler.toolchain.findFunction = ->
							throw "Test Unexpected Exception"
							
						compiler.processStderr.write.and.callFake ->
							expect(compiler.processExit).not.toHaveBeenCalled()						
							
						expect ->
								compiler configuration
								flushCallback()
								flushCallback()
								flushCallback()							
							.toThrow "Test Unexpected Exception"
						
						expect(compiler.processExit).not.toHaveBeenCalled()
						expect(compiler.processStdout.write).not.toHaveBeenCalled()
						expect(compiler.processStderr.write.calls.allArgs()).toEqual [["Unexpected error while compiling the source code:"]]					
				
			describe "when outputting native code", ->
				valueTests()
				
				it "writes to stderr and then rethrows when native code generation throws an unexpected exception", ->
					platformInstance.compile = ->
						throw "Test Unexpected Exception"
						
					compiler.processStderr.write.and.callFake ->
						expect(compiler.processExit).not.toHaveBeenCalled()						
						
					expect ->
							compiler configuration
							flushCallback()
							flushCallback()
							flushCallback()
						.toThrow "Test Unexpected Exception"
										
					expect(compiler.processExit).not.toHaveBeenCalled()
					expect(compiler.processStdout.write).not.toHaveBeenCalled()
					expect(compiler.processStderr.write.calls.allArgs()).toEqual [["Unexpected error while generating native code:"]]
				
				it "writes to stdout", ->					
					compiler configuration
					
					flushCallback()
					flushCallback()
					flushCallback()
					
					expect(compiler.processExit).not.toHaveBeenCalled()
					expect(compiler.processStderr.write).not.toHaveBeenCalled()
					expect(compiler.processStdout.write.calls.allArgs()).toEqual [["Test Native Code"]]
				
			describe "when outputting the pattern matching log", ->
				beforeEach ->
					configuration.mode = "patternMatchingLog"					
					
				valueTests()
								
				it "writes to stdout", ->					
					compiler configuration
					
					flushCallback()
					flushCallback()
					flushCallback()
					
					expect(compiler.processExit).not.toHaveBeenCalled()
					expect(compiler.processStderr.write).not.toHaveBeenCalled()
					expect(compiler.processStdout.write.calls.allArgs()).toEqual [["Test Log A\nTest Log B\nTest Log C"]]					
				
			describe "when outputting value JSON", ->
				beforeEach ->
					configuration.mode = "valueJson"
					
				valueTests()
								
				it "writes to stdout", ->
					compiler.jsonStringify.and.callFake (json, transform, tabs) ->
						expect(json).toEqual "Test Compiled Output"
						expect(transform).toBeNull()
						expect(tabs).toEqual "Test Tab Size"
						"Test Serialized Output"
						
					compiler configuration
					
					flushCallback()
					flushCallback()
					flushCallback()
					
					expect(compiler.processExit).not.toHaveBeenCalled()
					expect(compiler.processStderr.write).not.toHaveBeenCalled()
					expect(compiler.processStdout.write.calls.allArgs()).toEqual [["Test Serialized Output"]]
			
			describe "when outputting assertion results", ->
				beforeEach ->
					configuration.mode = "assertionResults"
				
				describe "when assertions are disabled", ->
					it "writes an error message to stderr as we can't output a disabled stage's result", ->							
						compiler.processStderr.write.and.callFake (param) ->
							expect(compiler.processExit).not.toHaveBeenCalled()
						
						compiler configuration
						
						expect(compiler.processStderr.write.calls.allArgs()).toEqual [["Cannot output assertion results when assertions are disabled using -a or --run-assertions"]]
						expect(compiler.processExit.calls.allArgs()).toEqual [[1]]
						expect(compiler.processStdout.write).not.toHaveBeenCalled()										
						
				describe "when assertions are enabled", ->
					beforeEach ->
						configuration.runAssertions = true
					
					tokenizeTests()
					
					it "writes to stdout on success", ->
						compiler.toolchain.runAssertions = (_tokenized) ->
							expect(_tokenized).toBe platformInstance
							expect(_tokenized.functions).toEqual "Test Tokenized"
							return [
									assertion:
										line:
											filename: "Test File A"
											line: 24
									resultType: "successful"
								,
									assertion:
										line:
											filename: "Test File B"
											line: 7
									resultType: "successful"
								,
									assertion:
										line:
											filename: "Test File A"
											line: 18
									resultType: "successful"
							]
						
						compiler configuration
						
						flushCallback()
						flushCallback()
						flushCallback()
						
						expect(compiler.processExit).not.toHaveBeenCalled()
						expect(compiler.processStderr.write).not.toHaveBeenCalled()
						expect(compiler.processStdout.write.calls.allArgs()).toEqual [["Test File A\n\tLine 18 - Successful\n\tLine 24 - Successful\nTest File B\n\tLine 7 - Successful"]]	
				
					it "writes to stdout on failure", ->
						compiler.toolchain.runAssertions = (_tokenized) ->
							expect(_tokenized).toBe platformInstance
							expect(_tokenized.functions).toEqual "Test Tokenized"
							return [
									assertion:
										line:
											filename: "Test File A"
											line: 18
									resultType: "successful"
								,
									assertion:
										line:
											filename: "Test File A"
											line: 24
									resultType: "failedToCompile"
								,
									assertion:
										line:
											filename: "Test File B"
											line: 7
									resultType: "didNotReturnPrimitiveConstant"
									output:
										parameter:
											type: "a type"
								,
									assertion:
										line:
											filename: "Test File B"
											line: 9
									resultType: "primitiveTypeNotAssertable"
									output:
										primitive:
											type: "test primitive a"
											value: 123
								,
									assertion:
										line:
											filename: "Test File B"
											line: 11
									resultType: "primitiveValueIncorrect"								
									output:
										primitive:
											type: "test primitive b"
											value: [4, 8, 5]
							]
						
						compiler configuration
						
						flushCallback()
						flushCallback()
						flushCallback()
						
						expect(compiler.processExit).not.toHaveBeenCalled()
						expect(compiler.processStderr.write).not.toHaveBeenCalled()
						expect(compiler.processStdout.write.calls.allArgs()).toEqual [["Test File A\n\tLine 18 - Successful\n\tLine 24 - Failed to compile\nTest File B\n\tLine 7 - Did not return a primitive constant\n\tLine 9 - Returned non-assertable primitive type \"test primitive a\": 123\n\tLine 11 - Returned unexpected primitive value of type \"test primitive b\": [4,8,5] whereas \"platform b primitive b assertion pass\" was expected"]]
			
			describe "when outputting tokenized JSON", ->
				beforeEach ->
					configuration.mode = "tokenizedJson"	
					
				tokenizeTests()
				
				it "writes to stdout", ->
					compiler.jsonStringify.and.callFake (json, transform, tabs) ->
						expect(json).toEqual "Test Tokenized"
						expect(transform).toBeNull()
						expect(tabs).toEqual "Test Tab Size"
						"Test Serialized Output"
						
					compiler configuration
					
					flushCallback()
					flushCallback()
					flushCallback()
					
					expect(compiler.processExit).not.toHaveBeenCalled()
					expect(compiler.processStderr.write).not.toHaveBeenCalled()
					expect(compiler.processStdout.write.calls.allArgs()).toEqual [["Test Serialized Output"]]						
				
			describe "when outputting file JSON", ->
				beforeEach ->
					configuration.mode = "fileJson"				
				
				fileTests()
				
				it "writes to stdout", ->	
					compiler.jsonStringify.and.callFake (json, transform, tabs) ->
						expect(json).toEqual 
							"Test Filename A": "Test File Content A"
							"Test Filename B": "Test File Content B"
							"Test Filename C": "Test File Content C"
						expect(transform).toBeNull()
						expect(tabs).toEqual "Test Tab Size"
						"Test Serialized Output"
						
					compiler configuration
					
					flushCallback()
					flushCallback()
					flushCallback()
					
					expect(compiler.processExit).not.toHaveBeenCalled()
					expect(compiler.processStderr.write).not.toHaveBeenCalled()
					expect(compiler.processStdout.write.calls.allArgs()).toEqual [["Test Serialized Output"]]				
				
			describe "when outputting input JSON", ->
				beforeEach ->
					configuration.mode = "inputJson"
				
				parameterTests()	
				
				it "writes to stdout", ->	
					compiler.jsonStringify.and.callFake (json, transform, tabs) ->
						expect(json).toEqual "Test Built Parameters"
						expect(transform).toBeNull()
						expect(tabs).toEqual "Test Tab Size"
						"Test Serialized Output"
							
					compiler configuration
					expect(compiler.processExit).not.toHaveBeenCalled()
					expect(compiler.processStderr.write).not.toHaveBeenCalled()
					expect(compiler.processStdout.write.calls.allArgs()).toEqual [["Test Serialized Output"]]