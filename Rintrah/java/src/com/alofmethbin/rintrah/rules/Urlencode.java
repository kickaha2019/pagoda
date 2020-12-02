package com.alofmethbin.rintrah.rules;

import com.alofmethbin.rintrah.Context;
import java.net.URLEncoder;

/**
 * String matching using regular expressions
 */
public class Urlencode extends Rule 
{
	// Constructor
	public Urlencode( String [] args)
	throws Exception
	{
		super( args);
		checkMinMaxArgs( 2, 2);
	}
	
    // Execute rule
    @Override
    public void execute(Context context) {
        try {
            Context subContext = context.duplicate();
            String value = evaluate(context, 0);
            subContext.put(this.getLiteral(1), URLEncoder.encode(value, "UTF-8"));
            subContext.execute();
        } catch (Throwable t) {
            error(context, t);
        }
    }
}
