package com.alofmethbin.rintrah.rules;

import com.alofmethbin.rintrah.Context;

/**
 * Position at next instance of given HTML element
 */
public class Next extends Rule 
{
    // Constructor

    public Next(String[] args)
            throws Exception {
        super(args);
        checkMinMaxArgs(1, 1);
    }

    // Execute rule
    public void execute(Context context) {
        try {
            Context sub = context.duplicate();
            int from = sub.getPosition();
            int to = sub.getLimit();

            // Advance to next occurrence of element tag
            for (int i = from + 1; i <= to; i++) {
                sub.setPosition(i);
                if (matchElement(sub, 0)) {
                    sub.execute();
                    return;
                }
            }
        } catch (Throwable t) {
            error(context, t);
        }
    }
}
