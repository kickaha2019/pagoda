package com.alofmethbin.rintrah.rules;

import com.alofmethbin.rintrah.Context;

/**
 * Rule keyword which doesn't mind if rule succeeds or not
 */
public class Endif extends Rule 
{
	// Constructor
	public Endif( String [] args)
	throws Exception
	{
		super( args);
		checkMinMaxArgs( 0, 0);
	}
	
	// Execute rule
	public void execute( Context context) 
	{
		// Execute remaining rules
		try {
			executed = true;
			Context sub = context.duplicate();
			sub.execute();	
			
		} catch (Throwable t) {
			error( context, t);
		}
	}
	
	// Clear executed flag
	protected void clearExecuted() {executed = false;}
	
	// Get executed flag
	protected boolean isExecuted() {return executed;}
	
	// Flag for this rule executed
	private boolean executed = false;
}
