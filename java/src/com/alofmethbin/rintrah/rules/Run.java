package com.alofmethbin.rintrah.rules;

import com.alofmethbin.rintrah.Branch;
import com.alofmethbin.rintrah.Context;
import com.alofmethbin.rintrah.Scanner;

/**
 * Run a named root or branch in a separate execution context
 */
public class Run extends Rule 
{
    // Constructor

    public Run(String[] args)
            throws Exception {
        super(args);
        checkMinMaxArgs(1, 99);
    }

    // Execute rule
    public void execute(Context context) {
        // Default script for rule to call to calling rule
        try {
            boolean logging = false;
            String name = getLiteral(0);
            if (name.indexOf("/") < 0) {
                name = getScript() + "/" + name;
            } else {
                logging = true;
                context.log( "Entering " + name);
            }

            // Prepare and execute context
            Branch branch = context.getBranch(name);
            Context subContext = branch.prepare(context, realise(context, 1));
            String oldName = context.setMonitor(Scanner.BRANCH, name);
            context.setReference(this.getReference());
            subContext.execute();
            context.clearReference();

            // Continue with rules after the run rule
            context.setMonitor(Scanner.BRANCH, oldName);
            subContext = context.duplicate();
            subContext.execute();
            if ( logging ) {context.log( "Leaving " + name);}
            
        } catch (Throwable t) {
            error(context, t);
        }
    }
}
