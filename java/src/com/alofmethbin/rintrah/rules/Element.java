package com.alofmethbin.rintrah.rules;

import com.alofmethbin.rintrah.Context;

/**
 * Get tag name for current HTML element
 */
public class Element extends Rule 
{
    // Constructor

    public Element(String[] args)
            throws Exception {
        super(args);
        checkMinMaxArgs(1, 1);
    }

    // Execute rule
    public void execute(Context context) {
        try {
            String value = context.getElement();
            Context subContext = context.duplicate();
            subContext.put( this.getLiteral(0), value.toUpperCase());
            subContext.execute();
        } catch (Throwable t) {
            error(context, t);
        }
    }
}
