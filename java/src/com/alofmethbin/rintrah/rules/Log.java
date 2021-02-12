package com.alofmethbin.rintrah.rules;

import com.alofmethbin.rintrah.Context;
import com.alofmethbin.rintrah.Scanner;

/**
 * Write line of values to standard error
 */
public class Log extends Rule 
{
    // Constructor

    public Log(String[] args)
            throws Exception {
        super(args);
        checkMinMaxArgs(1, 99);
    }

    // Execute rule
    public void execute(Context context) {
        try {
            Context subContext = context.duplicate();

            for (int i = 0; i < getArgumentCount(); i++) {
                if (i > 0) {System.err.print( " ");}
                System.err.print( trim( evaluate( context, i)));
            }

            System.err.println();
            subContext.execute();
        } catch (Throwable t) {
            error(context, t);
        }
    }

    // Trim string
    static protected String trim(String text) {
        text = text.trim();
        StringBuffer b = new StringBuffer();
        boolean white = false;
//		int first = Integer.MAX_VALUE, last = 0;

        if (text.startsWith("(The)")) {
            text = "The" + text.substring(5);
        }

        for (int i = 0; i < text.length(); i++) {
            char ch = text.charAt(i);
            if (Scanner.ALPHABET.indexOf(ch) < 0) {
                if (!white) {
                    white = true;
                    b.append(' ');
                }
            } else {
                white = false;
                b.append(ch);
//				if (Character.isLetterOrDigit( ch) || (ch == ')') || (ch == '/')) {
//					int j = b.length() - 1;
//					first = Math.min( first, j);
//					last = Math.max( last, j);
//				}
            }
        }

//		if (first == Integer.MAX_VALUE) {
//			return "";
//		}
//		return b.toString().substring( first, last+1);
        return b.toString().trim();
    }
}
