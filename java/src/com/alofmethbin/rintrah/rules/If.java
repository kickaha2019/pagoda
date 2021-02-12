package com.alofmethbin.rintrah.rules;

import java.util.List;

import com.alofmethbin.rintrah.Context;

/**
 * Rule keyword which doesn't mind if rule succeeds or not
 */
public class If extends Rule 
{
	// Constructor
	public If( String [] args)
	throws Exception
	{
		super( args);
		checkMinMaxArgs( 0, 0);
	}
	
	// Execute rule
	public void execute( Context context) 
	{
		// Find next Endif rule
		try {
			Context sub = context.duplicate();
			List<Rule> rules = sub.getRules();
			Endif endif = null;
			int depth = 0, endifAt = 0;
			
			for (int i = 0; (endif == null) && (i < rules.size()); i++) {
				if (rules.get( i) instanceof If) {
					depth ++;
				}
				if (rules.get( i) instanceof Endif) {
					if (depth == 0) {
						endifAt = i;
						endif = (Endif) rules.get( i);
						endif.clearExecuted();}
					else {
						depth --;
					}
				}
			}
			
			// Execute remaining rules
			sub.execute();	
			
			// If endif not executed then jump to it
			if ((endif != null) && (! endif.isExecuted())) {
				while (endifAt-- > 0) {
					sub = sub.duplicate();
				}
				sub.execute();
			}
			
		} catch (Throwable t) {
			error( context, t);
		}
	}
}
