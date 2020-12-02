package com.alofmethbin.rintrah.rules;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

import com.alofmethbin.rintrah.Context;

/**
 * String matching using regular expressions
 */
public class Match extends Rule 
{
	// Constructor
	public Match( String [] args)
	throws Exception
	{
		super( args);
		checkMinMaxArgs( 2, 4);
	}
	
	// Compose from "...{1}..." style string
	private String compose( Context context, Matcher matcher, String format)
	{
		StringBuffer buffer = new StringBuffer();
		
		for (int i = 0; i < format.length(); i++) {
			char ch = format.charAt( i);
			if (ch != '{') {
				buffer.append( ch);}
			else if (format.charAt( i+2) == '}') {
				buffer.append( matcher.group( Integer.parseInt( format.substring( i+1, i+2))));
				i += 2;}
			else {
				error( context, new Exception( "Bad format [" + format + "]"));
			}
		}
		
		return buffer.toString();
	}
	
    // Execute rule
    public void execute(Context context) {
        try {
            String value = evaluate(context, 0);
            String expr = evaluate(context, 1);
            Pattern pattern = Pattern.compile(expr, Pattern.CASE_INSENSITIVE);
            Matcher matcher = pattern.matcher(value);

            if (matcher.matches()) {
                Context subContext = context.duplicate();
                if (this.getArgumentCount() == 3) {
                    subContext.put(this.getLiteral(2), matcher.group(1));
                } else if (this.getArgumentCount() == 4) {
                    subContext.put(this.getLiteral(3), compose(context, matcher, evaluate(context, 2)));
                }
                subContext.execute();
            }
        } catch (Throwable t) {
            error(context, t);
        }
    }
}
