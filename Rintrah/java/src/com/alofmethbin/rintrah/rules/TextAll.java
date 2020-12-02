package com.alofmethbin.rintrah.rules;

import com.alofmethbin.rintrah.Context;

/**
 * Get value of text beneath current HTML element
 */
public class TextAll extends Rule 
{
    // Constructor

    public TextAll(String[] args)
            throws Exception {
        super(args);
        checkMinMaxArgs(1, 1);
    }

    // Execute rule
    public void execute(Context context) {
        try {
            String value = context.getTextAll();
            Context subContext = context.duplicate();
            subContext.put(getLiteral(0), value);
            subContext.execute();
        } catch (Throwable t) {
            error(context, t);
        }
    }
}
