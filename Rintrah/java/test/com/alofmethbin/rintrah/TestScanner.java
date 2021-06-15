package com.alofmethbin.rintrah;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.io.Reader;
import java.net.URL;
import java.util.ArrayList;
import java.util.List;

/**
 * Scanner sub-class for testing rules
 */
public class TestScanner extends Scanner {

    private String error;

    // Scanner context
    public class TestContext extends ScannerContext {

        @Override
        public File createTempFile() throws Exception {
            return File.createTempFile("cache", ".html");    
        }

        @Override
        public void error(String message) {
            error = message;
        }

        @Override
    public Reader fileReader(String path) throws Exception {
            URL url = this.getClass().getResource("resources/" + path + ".html");
                return new InputStreamReader(url.openStream());
    }

        @Override
        public File getCachedFile(String url) {
            return null;
        }
    
    @Override
    public boolean isDirectory(String path) {
        return false;
    }

        @Override
        public void saveCache(String url, File cached) {}

        @Override
        public String setMonitor(String key, String value) {
            return value;
        }
    }

    /**
     * Constructor
     * @param script Script to test
     */
    public TestScanner( String name) throws Exception {
        URL url = this.getClass().getResource( "resources/" + name + ".txt");
        load( "Test", new BufferedReader( new InputStreamReader( url.openStream())));
    }

    /**
     * Execute given branch
     * @param branch Branch name
     * @return Lines written
     */
    public List<String[]> execute( String branch) throws Exception {
        final List<String[]> written = new ArrayList<String[]>();
        this.execute("Test/" + branch, new WriteListener() {
            @Override
            public void write(String source, String[] args) throws Exception {
                written.add(args);
            }
        });
        return written;
    }
	
	/**
	 * Get new context
	 * @return New context
	 */
    @Override
	public Context getContext() {return new TestContext();}

    /**
     * Get error reported if any
     * @return null or error
     */
    public String getError() {return error;}
}
