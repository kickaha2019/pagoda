package com.alofmethbin.rintrah.rules;

import com.alofmethbin.rintrah.Context;
import com.alofmethbin.rintrah.WriteListener;
import java.util.regex.Pattern;

/**
 * Check for given line being written
 */
public class Expect extends Rule 
{
    // Constructor

    public Expect(String[] args)
            throws Exception {
        super(args);
        checkMinMaxArgs(1, 99);
    }
	
    // Execute rule
    @Override
    public void execute(Context context) {
        try {
            Context subContext = context.duplicate();

            expected = new String [getArgumentCount()];
            for (int i = 0; i < expected.length; i++) {
                expected[i] = Write.trim(evaluate(context, i));
            }

            seen = false;
            subContext.addWriteListener(new WriteListener() {
                public void write(String source, String[] args) throws Exception {
                    if (args.length < expected.length) {
                        return;
                    }
                    for (int i = 0; i < expected.length; i++) {
                        if ((! expected[i].equals( args[i])) && ! Pattern.matches( expected[i], args[i])) {
                            return;
                        }
                    }
                    seen = true;
                }
            });

            subContext.execute();

            if (!seen) {
                StringBuilder b = new StringBuilder();
                for (int i = 0; i < expected.length; i++) {
                    if (i > 0){b.append( ' ');}
                    b.append(expected[i]);
                }
                error(context, "Expected write [" + b.toString() + "] not seen", true);
            }
        } catch (Throwable t) {
            error(context, t);
        }
    }

    // Expected values
    private String [] expected;
	
    // Was expected write seen?
    private boolean seen = false;
}
