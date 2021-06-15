package com.alofmethbin.rintrah.rules;

import com.alofmethbin.rintrah.Context;

/**
 * Define a column for the scanner output
 */
public class Column extends Rule 
{
	// Constructor
	public Column( String [] args)
	throws Exception
	{
		super( args);
		checkMinMaxArgs( 2, 2);
	}

	// Execute rule
	public void execute( Context context)
	{
		try {
			context.addColumn( getLiteral( 0), getLiteral( 1));
			Context subContext = context.duplicate();
			subContext.execute();}
		catch (Throwable t) {
			error( context, t);
		}
	}
}
