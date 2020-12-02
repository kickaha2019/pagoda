package com.alofmethbin.rintrah;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.FileWriter;
import java.nio.charset.Charset;
import java.nio.charset.CharsetEncoder;

/**
 * Convert data file to HTML.
 * Arguments:
 * 
 * Input data file
 * Output HTML file
 */
public class Htmliser {

	/**
	 * @param args
	 */
	public static void main(String[] args) 
	{
		try {
			BufferedReader reader = new BufferedReader( new FileReader( args[0]));
			FileWriter writer = new FileWriter( args[1]);
			Charset latin = Charset.forName( "ISO-8859-1");
			CharsetEncoder encoder = latin.newEncoder();
			String line;
			int errors = 0, lineNumber = 0;
			
			writer.write( "<HTML><HEAD><TITLE>Title</TITLE></HEAD><BODY>\n");
			writer.write( "<TABLE>\n");
			
			while ((line = reader.readLine()) != null) {
				lineNumber ++;
				for (int i = 0; i < line.length(); i++) {
					char ch = line.charAt( i);
					if (ch == '\\') {
						System.err.println( "Line " + lineNumber + " contains \\ character");
						errors++;
						break;}
					else if (! encoder.canEncode( ch)) {
						System.err.println( "Line " + lineNumber + " contains weirdo character");
						errors++;
						break;
					}
				}
				String [] parts = Scanner.split( line);
				writer.write( "<TR>");
				for (int i = 0; i < parts.length; i++) {
					writer.write( "<TD>" + parts[i] + "</TD>");
				}
				writer.write( "</TR>\n");
			}
			
			writer.write( "</TABLE>\n");
			writer.write( "</BODY></HTML>\n");
			writer.close();
			System.exit( (errors == 0) ? 0 : 1);
		}
		catch (Throwable t) {
			t.printStackTrace();
			System.exit( 1);
		}
	}
}
