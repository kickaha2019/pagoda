package com.alofmethbin.rintrah;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.util.ArrayList;
import java.util.List;

/**
 * Patch games / alias data files with sort versions of game names
 */
public class PrettySort {

	/**
	 * @param args
	 */
	public static void main( String[] args) {

		// Open input and output files
		try {
			BufferedReader reader = new BufferedReader( new FileReader( args[0]));
			FileWriter writer = new FileWriter( new File( args[1]));
			
			// Get positions of name and sort name from first line
			String line = reader.readLine();
			writer.write( line + "\n");
			String [] parts = Scanner.split( line);
			int sortColumn = -1;
			int nameColumn = -1;
			
			for (int i = 0; i < parts.length; i++) {
				if ( "sort_name".equals( parts[i]) ) {sortColumn = i;}
				if ( "name".equals( parts[i]) ) {nameColumn = i;}
			}
			
			if ((sortColumn < 0) || (nameColumn < 0)) {
				throw new Exception( "sort name or name column not found in " + args[0]);
			}
			
			// Loop through lines
			while ((line = reader.readLine()) != null) {
				if (line.trim().length() < 1) {continue;}
				parts = Scanner.split( line);
				String name = parts[ nameColumn];
				
				// Derive sort name from name
				parts[ sortColumn] = toSort( args[0], name);
				
				// Write out modified line
				for (int i = 0; i < parts.length; i++) {
					if (i > 0) {writer.write( "\t");}
					writer.write( parts[i]);
				}
				
				writer.write( "\n");
			}
			
			// Finish
			reader.close();
			writer.close();
		}
		
		catch (Throwable t) {
			t.printStackTrace();
			System.exit( 1);
		}
	}

	// Convert name to pretty sort name
	private static String toSort( String ref, String name)
	{
		List<String> words = new ArrayList<String>();
		Collator.crunch( ref, name, words);
		
		if (words.size() > 0) {
			String first = words.get( 0);
			if ("the".equals( first) || "a".equals( first) || "an".equals( first)) {
				words.remove( 0);
				words.add( first);
			}
		}
		
		StringBuffer b = new StringBuffer();
		
		if ((words.size() < 1) || (! Character.isLetter( words.get( 0).charAt( 0)))) {
			b.append( '#');
		}
		
		for (int i = 0; i < words.size(); i++) {
			if (i > 0) {b.append( ' ');}
			String word = words.get( i);
			try {
				int n = Integer.parseInt( word);
				if ((n > 0) && (n < 100)) {
					b.append( Integer.toString( 100 + n).substring( 1));}
				else {
					b.append( word);
				}
			}
			catch (NumberFormatException nfe) {
				b.append( word);
			}
		}
		
		return b.toString().toUpperCase();
	}
}
