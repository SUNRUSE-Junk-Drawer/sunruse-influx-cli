# Given:
#	The platform instance.
#	An array of parameter names in the format:
# 		(property name).(property name).(primitive type name or literal)
# Returns:
#	A value object representing these parameters.
#	When the input is empty, an empty properties object is returned.
# Throws:
#	JSON objects describing the error encountered.
#		reason: String specifying the kind of error.
#			"parameterDefinedMultipleTimes": Two or more different
#				parameters in the input define the same property.  This can
#				occur when a property is specified multiple times as a
#				primitive parameter or constant, or when a primitive parameter
#				or constant is also specified as part of a property chain.
#					"chain": Array of strings; the property chain where the 
#						conflict occurred.
#					"parameter": The parameter string which triggered the 
#						conflict.
#			"primitiveTypeOrLiteralUnrecognized": A primitive parameter was 
#				defined with an unrecognized type.
#					"chain": Array of strings; the property chain where the 
#						problem occurred.
#					"type": The unrecognized type name.
module.exports = (platform, parameters) ->
	input = {}
	
	if parameters
		for parameter in parameters
	
			tokens = parameter.split ">"	
			found = input
		
			while tokens.length > 1
				if found.parameter or found.primitive
					chain = parameter.split ">"
					chain.pop() for [0 ... tokens.length]
					throw 
						reason: "parameterDefinedMultipleTimes"
						chain: chain
						parameter: parameter
					
				if not found.properties
					found.properties = {}
				if not found.properties[tokens[0]]
					found.properties[tokens[0]] = {}
					
				found = found.properties[tokens[0]]
					
				tokens.shift()
		
			if found.properties or found.parameter or found.primitive
				chain = parameter.split ">"
				chain.pop()
				throw 
					reason: "parameterDefinedMultipleTimes"
					chain: chain
					parameter: parameter
		
			for primitiveName of platform.primitives
				parsed = platform.primitives[primitiveName].parse tokens[0]
				if parsed isnt undefined
					found.primitive =
						type: primitiveName
						value: parsed
					break
		
			if found.primitive then continue
		
			if not platform.primitives[tokens[0]]
				chain = parameter.split ">"
				chain.pop() for [0 ... tokens.length]		
				throw
					reason: "primitiveTypeOrLiteralUnrecognized"
					type: tokens[0]
					chain: chain
		
			found.parameter =
				type: tokens[0]
	
	if not (input.properties or input.parameter or input.primitive)
		input = 
			properties: {}	

	recurseScore = (val) ->
		if val.properties
			val.score = 0
			for name of val.properties
				val.score += recurseScore val.properties[name]
		else
			val.score = 1
		val.score
		
	recurseScore input
	
	input