package com.alofmethbin.rintrah.rules;

import java.util.List;

import com.alofmethbin.rintrah.Branch;
import com.alofmethbin.rintrah.Context;
import com.alofmethbin.rintrah.Scanner;

/**
 * Call a branch or root in a new stack
 */
public class Call extends Rule 
{
	// Special rule to chain on rule execution
	class ChainRule extends Rule {
		ChainRule( List<Rule> rules, Context base, String reference) throws Exception
		{
			super( new String [0]);
			this.base = base;
			this.reference = reference;
			this.rules = rules;
		}
		public void execute( Context context) 
		{
			try {
				Context subContext = context.duplicate();
				subContext.setRules( rules);
				base.clearReference();
				subContext.execute();
				base.setReference( reference);
			} catch (Throwable t) {
				Call.this.error( context, t);
			}
		}
		public boolean validate() {return true;}
		private Context base;
		private String reference;
		private List<Rule> rules;
	}
	
	// Constructor
	public Call( String [] args)
	throws Exception
	{
		super( args);
		checkMinMaxArgs( 1, 99);
	}
	
    // Execute rule
    public void execute(Context context) {
        // Default script for rule to call to calling rule
        try {
            boolean logging = false;
            String name = this.getLiteral(0);
            if (name.indexOf("/") < 0) {
                name = getScript() + "/" + name;
            } else {
                logging = true;
                context.log( "Entering " + name);
            }

            // Create special rule which will execute remaining
            // rules after the call in the passed in context
            Context temp = context.duplicate();
            ChainRule chain = new ChainRule(temp.getRules(), context, getReference());

            // Prepare context
            Branch branch = context.getBranch(name);
            Context subContext = branch.prepare(context, realise(context, 1));
            context.setReference(this.getReference());

            // Append special rule which will execute remaining
            // rules after the call in the passed in context
            List<Rule> rules = subContext.getRules();
            rules.add(chain);
            subContext.setRules(rules);

            // Execute branch
            String oldName = context.setMonitor(Scanner.BRANCH, name);
            subContext.execute();
            context.clearReference();
            context.setMonitor(Scanner.BRANCH, oldName);
            if ( logging ) {context.log( "Leaving " + name);}

        } catch (Throwable t) {
            error(context, t);
        }
    }
}
