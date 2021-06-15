package com.alofmethbin.rintrah.rules;

import com.alofmethbin.rintrah.Context;

/**
 * Get value of given attribute for current HTML element
 */
public class Attribute extends Rule 
{
    // Constructor

    public Attribute(String[] args)
            throws Exception {
        super(args);
        checkMinMaxArgs(2, 2);
    }

    // Execute rule
    public void execute(Context context) {
        try {
            String value = context.getAttribute(this.getLiteral(0));
            Context subContext = context.duplicate();
            subContext.put(this.getLiteral(1), (value != null) ? value : "");
            subContext.execute();
        } catch (Throwable t) {
            error(context, t);
        }
    }
}
