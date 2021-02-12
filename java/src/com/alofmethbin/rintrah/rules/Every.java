package com.alofmethbin.rintrah.rules;

import com.alofmethbin.rintrah.Context;
import com.alofmethbin.rintrah.PrunableContext;

/**
 * Loop over every instance of given HTML element
 */
public class Every extends Rule 
{
    // Constructor

    public Every(String[] args)
            throws Exception {
        super(args);
        checkMinMaxArgs(1, 1);
    }
	
    // Execute rule
    public void execute(Context context) {
        try {
            Context sub = context.duplicate();
            sub = new PrunableContext(sub) {

                public void prune() {
                    setPosition(getLimit() + 1);
                }
            };
            while (sub.getPosition() <= sub.getLimit()) {
                if (matchElement(sub, 0)) {
                    sub.execute();
                }
                sub.setPosition(sub.getPosition() + 1);
            }
        } catch (Throwable t) {
            error(context, t);
        }
    }
}
