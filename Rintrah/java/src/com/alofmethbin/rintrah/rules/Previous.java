package com.alofmethbin.rintrah.rules;

import com.alofmethbin.rintrah.Context;

/**
 * Position at previous instance of given HTML element
 */
public class Previous extends Rule 
{
	// Constructor
	public Previous( String [] args)
	throws Exception
	{
		super( args);
		checkMinMaxArgs( 1, 1);
	}
	
	// Execute rule
	public void execute( Context context) 
	{
		try {
			Context sub = context.duplicate();
			int from = sub.getPosition();
			
			// Regress to last occurrence of element tag
			for (int i = from-1; i >= 0; i--) {
				sub.setPosition( i);
				if ( matchElement( sub, 0) ) {
					sub.execute();
					return;
				}
			}}
		catch (Throwable t) {
			error( context, t);
		}
	}
}
