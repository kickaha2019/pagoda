package com.alofmethbin.rintrah.rules;

import com.alofmethbin.rintrah.Context;
import com.alofmethbin.rintrah.Scanner;

/**
 * Write line of values to the context
 */
public class Write extends Rule 
{
    // Constructor

    public Write(String[] args)
            throws Exception {
        super(args);
        checkMinMaxArgs(1, 99);
    }

    // Execute rule
    public void execute(Context context) {
        try {
            Context subContext = context.duplicate();
            String[] line = new String[getArgumentCount()];

            for (int i = 0; i < line.length; i++) {
                line[i] = trim(evaluate(context, i));
            }

            context.write(null, line);
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
