package com.alofmethbin.rintrah;

import java.io.File;
import java.io.FileReader;
import java.io.LineNumberReader;

/**
 * Check for unexpected characters in one or more text files
 */
public class CheckChars {

    // Expected characters in text
    public static String EXPECTED =
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789[]()/&'\",.;:!?_=-+*#%~$@ \t\n\r";

    /**
     * @param args List of files to check
     */
    public static void main(String[] args) {
        try {
            int nErrors = 0;
            for (String a : args) {
                nErrors += checkFile(new File(a));
            }
            if (nErrors > 0) {
                System.out.println(nErrors + " errors found");
                System.exit(1);
            }
        } catch (Throwable t) {
            t.printStackTrace();
            System.exit(1);
        }
    }

    // Check given file
    private static int checkFile(File f) throws Exception {
        int nErrors = 0;
        LineNumberReader reader = new LineNumberReader(new FileReader(f));
        System.out.println("Checking file [" + f.getAbsolutePath() + "]");
        String line;
        while ((line = reader.readLine()) != null) {
            StringBuffer badChars = new StringBuffer();
            for (int i = 0; i < line.length(); i++) {
                char ch = line.charAt(i);
                if (EXPECTED.indexOf(ch) < 0) {
                    badChars.append(ch);
                }
            }
            if (badChars.length() > 0) {
                nErrors++;
                System.out.println("  Line " + reader.getLineNumber() + ": [" + badChars.toString() + "]");
            }
        }
        reader.close();
        return nErrors;
    }
}
