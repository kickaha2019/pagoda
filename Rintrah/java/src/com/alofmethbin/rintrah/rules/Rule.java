package com.alofmethbin.rintrah.rules;

import java.util.ArrayList;
import java.util.List;

import com.alofmethbin.rintrah.Context;

/**
 * Script rule which represents a scanning directive
 */
public abstract class Rule 
{
	// Constructor
	public Rule( String [] args)
		throws Exception
	{
		List<List<String>> exprs = new ArrayList<List<String>>();
		boolean merge = false;
		
		for (int i = 0; i < args.length; i++) {
			if ( "+".equals( args[ i]) ) {
				if (merge || (i == 0)) {
					throw new Exception( "Bad syntax");}
				else {
					merge = true;
				}}
			else if ( merge ) {
				exprs.get( exprs.size() - 1).add( args[ i]);
				merge = false;}
			else {
				List<String> expr = new ArrayList<String>();
				expr.add( args[i]);
				exprs.add( expr);
			}
		}
		
		this.exprs = exprs;
	}

	/**
	 * Check number of arguments in range
	 * @param min Min arguments
	 * @param max Max arguments
	 * @return true iff valid
	 */
	public void checkMinMaxArgs( int min, int max)
		throws Exception
	{
		if ((exprs.size() < min) || (exprs.size() > max)) {
			throw new Exception( "Bad number of arguments");
		}
	}
	
	/**
	 * Raise error on rule
	 * @param context Context
	 * @param message Error message
	 */
	public void error( Context context, String message, boolean always) 
	{
		if (always || (! errored)) {
			context.setReference(reference);
			context.error( message);
			context.clearReference();
			errored = true;
		}
	}

    /**
     * Raise error on exception
     * @param context Context
     * @param thrown Exception
     */
    public void error(Context context, Throwable thrown) {
        if (!errored) {
            error(context, thrown.getMessage(), false);
            //thrown.printStackTrace( System.err);
        }
    }
	
	/**
	 * Evaluate argument
	 * @param context Context
	 * @param index Argument index
	 * @return Argument value
	 * @throws Exception no such argument
	 */
	public String evaluate( Context context, int index)
		throws Exception
	{
		List<String> expr = exprs.get( index);
		StringBuffer b = new StringBuffer();
		for (int i = 0; i < expr.size(); i++) {
    		b.append( context.get( expr.get( i)));
		}
		return b.toString();
	}

    /**
     * Evaluate value as an integer
     * @param context Context
     * @param index Argument index
     * @return Value
     */
    public int evaluateInt(Context context, int index) throws Exception {
        return Integer.parseInt( evaluate( context, index));
    }
	
	/**
	 * Execute rule
	 * @param context Current context
	 */
	public void execute( Context context) 
	{
		error( context, "Execute not implemented", false);
	}
	
	/**
	 * Get number of arguments
	 * @return Argument count
	 */
	public int getArgumentCount() {return exprs.size();}
	
	/**
	 * Get literal rule argument
	 * @return Literal rule argument 
	 * @throws Exception no such literal argument
	 */
	public String getLiteral( int index)
		throws Exception
	{
		List<String> expr = exprs.get( index);
		if (expr.size() > 1) {
			throw new Exception( "Compound argument");
		}
		String value = expr.get( 0);
		if ( value.startsWith( "\"") ) {value = value.substring( 1, value.length() - 1);}
		return value;
	}
	
	/**
	 * Get reference
	 * @return Reference
	 */
	public String getReference() {return reference;}
	
	/**
	 * Get script
	 * @return Script
	 */
	public String getScript() {return script;}

	/**
	 * Check for at element with desired name
	 * @param context Context
	 * @param literal Index of literal giving desired name
	 */
	public boolean matchElement( Context context, int literal) throws Exception
	{
            String tag = context.getElement();
            if (tag == null) {return false;}
            String elementName = this.getLiteral( 0);
            if ( "*".equals( elementName) ) {return true;}
            return elementName.equalsIgnoreCase( tag);
	}
	
	/**
	 * Realise rule arguments
	 * @param context Context
	 * @return Realised arguments
	 */
	protected String [] realise( Context context, int offset)
		throws Exception
	{
		String [] sliced = new String [ getArgumentCount() - offset];
		
		for (int i = 0; i < sliced.length; i++) {
			sliced[ i] = evaluate( context, i + offset);
		}
		
		return sliced;
	}
	
	/**
	 * Set reference
	 * @param reference
	 */
	public void setReference( String reference)
	{
		String cn = getClass().getName();
		cn = cn.substring( cn.lastIndexOf( '.') + 1);
		this.reference = reference + " [" + cn + "]";
	}
	
	/**
	 * Set script
	 * @param script
	 */
	public void setScript( String script)
	{
		this.script = script;
	}
	
	// Data
	private List<List<String>> exprs;
	private boolean errored = false;
	private String reference;
	private String script;
}
