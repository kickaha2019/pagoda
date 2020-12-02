package com.alofmethbin.rintrah.rules;

import com.alofmethbin.rintrah.Context;

/**
 * Get value of text following current HTML element
 */
public class Text extends Rule 
{
	// Constructor
	public Text( String [] args)
	throws Exception
	{
		super( args);
		checkMinMaxArgs( 1, 1);
	}
	
	// Execute rule
	public void execute( Context context) 
	{
		try {
			String value = context.getText();
			Context subContext = context.duplicate();
			subContext.put( getLiteral( 0), value);
			subContext.execute();}
		catch (Throwable t) {
			error( context, t);
		}
	}
}
