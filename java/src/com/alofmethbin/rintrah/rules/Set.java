package com.alofmethbin.rintrah.rules;

import com.alofmethbin.rintrah.Context;

/**
 * Set value for key ARGS[0] to the concatenation of ARGS[1..]
 * (if ARGS[1+] is a "" delimited string use the string value,
 * else take ARGS[1+] as a key name and get its value from the
 * context) 
 */
public class Set extends Rule 
{
	// Constructor
	public Set( String [] args)
	throws Exception
	{
		super( args);
		checkMinMaxArgs( 2, 2);
	}
	
	// Execute rule
	public void execute( Context context)
	{
		try {
			Context subContext = context.duplicate();
			String key = getLiteral( 0);
			subContext.put( key, evaluate( context, 1));
			subContext.execute();}
		catch (Throwable t) {
			error( context, t);
		}
	}
}
