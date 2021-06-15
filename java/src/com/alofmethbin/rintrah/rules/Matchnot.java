package com.alofmethbin.rintrah.rules;

import com.alofmethbin.rintrah.Context;

/**
 * String matching using regular expressions (which succeeds
 * if match fails)
 */
public class Matchnot extends Rule
{
	// Constructor
	public Matchnot( String [] args)
	throws Exception
	{
		super( args);
		checkMinMaxArgs( 2, 2);
	}
	
	// Execute rule
	public void execute( Context context) 
	{
		try {
			String value = evaluate( context, 0);
			String expr = evaluate( context, 1);
			
			if (! value.matches( expr)) {
				Context subContext = context.duplicate();
				subContext.execute();
			}}
		catch (Throwable t) {
			error( context, t);
		}
	}
}
