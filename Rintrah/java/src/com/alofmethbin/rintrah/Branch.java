package com.alofmethbin.rintrah;

import java.util.ArrayList;
import java.util.List;

import com.alofmethbin.rintrah.rules.Rule;

/**
 * Represent a branch or root
 */
public class Branch 
{
	/**
	 * Constructor
	 * @param params Parameter names
	 */
	public Branch( String [] params)
	{
		this.params = params;
	}
	
	/**
	 * Prepare context for execution of branch
	 * @param context Context
	 * @param args Argument list
	 * @return Prepared context
	 */
	public Context prepare( Context context, String [] args)
		throws Exception
	{
		Context subContext = context.duplicate();

		subContext.setRules( new ArrayList<Rule>( rules));
		
		if (args.length != params.length) {
			throw new Exception( "Wrong number of arguments");
		}
		
		for (int i = 0; i < params.length; i++) {
			subContext.put( params[i], args[i]);
		}
		
		return subContext;
	}
	
	// Parameters
	public String [] params;
	
	// Rules
	public List<Rule> rules = new ArrayList<Rule>();
}
