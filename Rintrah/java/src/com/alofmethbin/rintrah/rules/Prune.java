package com.alofmethbin.rintrah.rules;

import com.alofmethbin.rintrah.Context;

/**
 * Prune iteration
 */
public class Prune extends Rule 
{
    // Constructor

    public Prune(String[] args)
            throws Exception {
        super(args);
        checkMinMaxArgs(0, 0);
    }

    // Execute rule
    public void execute(Context context) {
        try {
            Context subContext = context.duplicate();
            context.prune();
            subContext.execute();
        } catch (Throwable t) {
            error(context, t);
        }
    }
}
