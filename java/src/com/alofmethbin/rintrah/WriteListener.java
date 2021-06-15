package com.alofmethbin.rintrah;

/**
 * Listener for write events
 */
public interface WriteListener {

	/**
	 * Notify write call made
	 * @param source Source for data
	 * @param args Write call arguments
	 */
	public void write( String source, String [] args) throws Exception;
}
