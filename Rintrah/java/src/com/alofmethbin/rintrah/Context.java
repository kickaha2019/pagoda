package com.alofmethbin.rintrah;

import com.alofmethbin.rintrah.rules.Rule;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.LineNumberReader;
import java.io.Reader;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;

/**
 * Execution context for rules
 */
public abstract class Context 
{
    // Part of HTML file
    private class Part {
        String text;
        Properties attributes;

        private Part( String text) {
            this.text = text;
        }

        private Part(String name, Properties map) {
            this.text = name;
            this.attributes = map;
        }

        boolean isElement() {return attributes != null;}
        boolean isText() {return attributes == null;}
    }

    // Token getter for HTML
    private class HTMLGetter {
        LineNumberReader reader;
        char [] ungot = null;

        HTMLGetter( Reader reader) {this.reader = new LineNumberReader( new BufferedReader(reader));}

        char [] get() throws Exception {
            char [] ch = ungot;
            if (ch == null) {
                ch = new char [1];
                if (reader.read( ch) < 1) {return null;}
            }
            ungot = null;
            return ch;
        }

        String getName() throws Exception {
            StringBuilder b = new StringBuilder();
            char [] ch = get();
            while ((ch != null) && isWhitespace( ch[0])) {
                ch = get();
            }
            while ((ch != null) && isNameChar( ch[0])) {
                b.append( ch[0]);
                ch = get();
            }
            unget( ch);
            return (b.length() > 0) ? b.toString().toLowerCase() : null;
        }

        String getText() throws Exception {
            StringBuilder b = new StringBuilder();
            char [] ch = get();
            if (ch == null) {return null;}
            while ((ch != null) && (ch[0] != '<')) {
                if ( isWhitespace( ch[0]) ) {ch[0] = ' ';}
                b.append( ch[0]);
                ch = get();
            }
            String text = b.toString();
            text = text.replace( "&nbsp;", " ");
            return text.trim();
        }

        String getValue() throws Exception {
            StringBuilder b = new StringBuilder();
            char [] ch = get();
            while ((ch != null) && isWhitespace( ch[0])) {
                ch = get();
            }
            if (ch == null) {
                return null;
            } else if (ch[0] == '"' || ch[0] == '\'') {
                char delim = ch[0];
                ch = get();
                while ((ch != null) && (ch[0] != delim)) {
                    b.append( ch[0]);
                    ch = get();
                }
            } else {
                while ((ch != null) && (ch[0] != ' ') && (ch[0] != '>')) {
                    b.append( ch[0]);
                    ch = get();
                }
                unget( ch);
            }
            return b.toString();
        }

        boolean isNameChar( char ch) {
            return Character.isLetter( ch) || Character.isDigit( ch) || (ch == '!') || (ch == '-') || (ch == '/') || (ch == '?');
        }

        boolean isPunct( char ch) {
            return (ch < 0) || (ch == '<');
        }

        boolean isWhitespace( char ch) {
            return Character.isWhitespace( ch) || Character.isSpaceChar( ch);
        }

        private boolean next( char mark) throws Exception {
            char [] ch;
            while ((ch = get()) != null) {
                if (! isWhitespace( ch[0])) {break;}
            }
            if ((ch != null) && (ch[0] == mark)) {return true;}
            unget( ch);
            return false;
        }

        boolean skip( String mark) throws Exception {
            int matched = 0;

            while (matched < mark.length()) {
                char [] ch = get();
                if (ch == null) {
                    System.err.println( "[" + mark + "] not found");
                    return false;
                } else if (ch[0] == mark.charAt( matched)) {
                    matched++;
                } else {
                    matched = 0;
                }
            }
            
            return true;
        }

        public void skipScript() throws Exception {
            while (true) {
                if (!skip("<")) {
                    return;
                }

                if ("/script".equals(getName())) {
                    skip(">");
                    return;
                }
            }
        }

        void unget( char [] ch) {ungot = ch;}
    }

    /**
     * Define column in output
     * @param name Column name
     * @param defval Default value
     */
    public void addColumn(String name, String defval) throws Exception {
        if (parent != null) {
            parent.addColumn(name, defval);
        }
    }

	/**
	 * Add write listener
	 * @param listener Write listener
	 */
	public void addWriteListener( WriteListener listener) {
		listeners.add( listener);
	}

	/**
	 * Clear reference
	 */
	public void clearReference() {
		reference = null;
	}
	
	/**
	 * Copy existing context
	 * @param base Context to be copied
	 * @throws Exception on copy error
	 */
	public void copy( Context base)
	throws Exception
	{
		// Copy the HTML document reference and position / limit
		html = base.html;
		source = base.source;
		position = base.position;
		limit = base.limit;

		// Copy the key values
		keyValues.putAll( base.keyValues);

		// Reference same rules but move index on one
		rules = base.rules;
		ruleIndex = base.ruleIndex + 1;

		// Remember parent context
		parent = base;
	}

     /**
      * Create cache file
      * @return Cache file
      * @throws Exception 
      */
    public File createTempFile() throws Exception {
        return File.createTempFile("cache", ".html");
    }
    
    /**
     * Dump stack
     */
    public void dumpStack() {
        if (reference != null) {
            log(reference);
        }
        if (parent != null) {
            parent.dumpStack();
        }
    }
	
    /**
     * Duplicate context
     *
     * @return Copy of context
     * @throws Exception on duplication error
     */
    public abstract Context duplicate()
            throws Exception;

    /**
     * Raise error
     *
     * @param message Error message
     */
    public abstract void error(String message);

    /**
     * Execute next rule (if any)
     */
    public void execute() {
        execute(this);
    }

    protected void execute(Context owner) {
        if (ruleIndex < rules.size()) {
            Rule r = rules.get(ruleIndex);
            r.execute(owner);
        }
    }

    /**
     * Return reader for file
     * @param path File path
     * @return File reader
     * @throws FileNotFoundException 
     */
    public Reader fileReader(String path) throws Exception {
        return new FileReader( path);
    }

    /**
     * Get value for expression
     * @param expr Expression
     * @return Value for expression or null
     */
    public String get(String key) throws Exception {
        if (key.startsWith("\"")) {
            return key.substring(1, key.length() - 1);
        } else if (Character.isDigit(key.charAt(0))) {
            return key;
        } else if (!keyValues.containsKey(key)) {
            throw new Exception(key + " not defined");
        } else {
            return keyValues.get(key);
        }
    }

    /**
     * Get attribute value for current position in HTML document
     * @param name Attribute name
     * @return null or attribute value
     */
    public String getAttribute(String name) {
        if (html == null) {
            return null;
        }
        if ((position < 0) || (position >= html.size())) {
            return null;
        }
        Part part = (Part) html.get(position);

        if (part.attributes != null) {
            return part.attributes.getProperty( name.toLowerCase());
        }

        return null;
    }

	/**
	 * Find branch object for given branch or root
	 * @param name Branch or root name
	 * @return Branch
	 * @throws Exception if branch / root not found
	 */
	public abstract Branch getBranch( String name) throws Exception; 

	/**
	 * Get cached file for URL
	 * @param url URL
	 * @return null or URL
	 */
	public abstract File getCachedFile( String url);

    /**
     * Get element name for current position in HTML document
     * @return null or element name
     */
    public String getElement() {
        if (html == null) {return null;}
        if ((position < 0) || (position > html.size())) {return null;}
        Part part = (Part) html.get(position);

        if ( part.isElement() ) {return part.text;}
        return null;
    }

	/**
	 * Get value for expression
	 * @param expr Expression
	 * @return Value for expression
	 */
	public int getInt( String key)
	throws Exception
	{
            return Integer.parseInt( get( key));
        }

	/**
	 * Get limit in HTML file
	 * @return Limit
	 */
	public int getLimit() {return limit;}

	/**
	 * Get position in HTML file
	 * @return Position
	 */
	public int getPosition() {return position;}

	/**
	 * Get remaining rules for context
	 * @return Remaining rules for context
	 */
	public List<Rule> getRules()
	{
		List<Rule> todo = new ArrayList<Rule>();
		for (int i = ruleIndex; i < rules.size(); i++) {
			todo.add( rules.get( i));
		}
		return todo;
	}

    /**
     * Get text value for current position in HTML document
    * @return Text value
    */
    public String getText()
    {
        if (html == null) {return "";}
        if (position < 0) {return "";}
        StringBuilder b = new StringBuilder();

        for (int i = position+1; i < html.size(); i++) {
            Part part = (Part) html.get( i);
            if ( part.isText() ) {
                b.append( part.text);}
            else {
                break;
            }
        }

        return b.toString();
    }

    /**
     * Get text value beneath current position in HTML document
    * @return Text value
    */
    public String getTextAll()
    {
        String el = getElement();
        if ((el == null) || el.startsWith( "/")) {return "";}
        StringBuilder b = new StringBuilder();

        for (int i = position+1; i < html.size(); i++) {
            Part part = (Part) html.get( i);
            if ( part.isText() ) {
                b.append( part.text);}
            else if ( part.isElement() ) {
                if ( part.text.equals( "/" + el) ) {break;}
                b.append( ' ');
            }
        }

        return reduce( b.toString().trim());
    }

    /**
     * Test for new HTTP loads allowed
     * @return true iff allowed
     */
    public boolean httpLoadNew() {
        if (parent != null) {
            return parent.httpLoadNew();
        } else {
            return true;
        }
    }

    /**
     * Test for path being a directory
     * @param path Directory path
     * @return true iif a directory
     */
    public boolean isDirectory(String path) {
        return new File( path).isDirectory();
    }

    /**
     * Load HTML document from reader
     * @param reader Reader to load document from
     */
    public void load( String source, Reader reader) throws Exception {
        this.source = source;
        position = 0;
        limit = -1;
        html = new ArrayList<Object>();

        // If plugin specified use to convert document
//        if (pluginName != null) {
//            URLPlugin plugin = (URLPlugin) Class.forName( pluginName).newInstance();
//            reader = new StringReader( plugin.convert( reader));
//        }

        HTMLGetter getter = new HTMLGetter( reader);
        while ( true ) {
            String text = getter.getText();
            if (text == null) {break;}
            html.add( new Part( text));
            String name = getter.getName();
            if (name == null) {break;}

            if ( name.equals( "!--") ) {
                getter.skip( "-->");
                continue;
            }

            if ( name.equals( "script") ) {
                getter.skipScript();
                continue;
            }

            if (name.startsWith( "!") || name.startsWith( "?")) {
                getter.skip( ">");
                continue;
            }

            Properties map = new Properties();
            while ( true ) {
                String key = getter.getName();
                if ((key == null) || key.equals( "/")) {break;}
                if (! getter.next( '=')) {break;}
                String value = getter.getValue();
                map.setProperty( key, value);
            }
            html.add( new Part( name, map));

            getter.skip( ">");
        }

	limit = html.size() - 1;
    }

    /**
     * Log message
     *
     * @param message
     */
    public void log(String message) 
    {
        if (parent != null) {
            parent.log(message);
        }
    }
	
    /**
     * Make a rule
     *
     * @param name Rule name
     * @param args Rule arguments
     * @param ref Reference
     */
    public Rule makeRule(String name, String[] args, String ref) {
        if (parent != null) {
            return parent.makeRule(name, args, ref);
        }
        return null;
    }
	
    /**
     * Prune iteration
     */
    public void prune() {
        if (parent != null) {
            parent.prune();
        }
    }

    /*
     * Set value for key
     * @param key Key
     * @param value Value
     */
    public void put(String key, String value) {
        keyValues.put(key, value);
    }

    /*
     * Set value for key
     * @param key Key
     * @param value Value
     */
    public void put(String key, int value) {
        keyValues.put(key, Integer.toString(value));
    }
    
    // Record file being loaded
    public void recordCacheFile(File cacheFile) {
        if (parent != null) {
            parent.recordCacheFile( cacheFile);
        }
    }

    /**
     * Reduce multiple whitespace characters to single blanks
     * @param text text to reduced
     * @return Reduced text
     */
    private String reduce(String text) {
        StringBuilder b = new StringBuilder();
        boolean lastWhite = false;
        for (int i = 0; i < text.length(); i++) {
            char ch = text.charAt( i);
            if ( Character.isWhitespace( ch) ) {
                if (! lastWhite) {
                    lastWhite = true;
                    b.append( ' ');
                }
            } else {
                lastWhite = false;
                b.append( ch);
            }
        }
        return b.toString();
    }

    /**
     * Save HTTP page to cached file
     * @param url URL
     * @param cached Cached file
     */
    public void saveCache(String url, File cached) throws Exception
    {
        if (parent != null) {
            parent.saveCache( url, cached);
        }
    }

	/**
	 * Set limit in HTML file
	 * @param limit New limit
	 */
	//public void setLimit( int limit) {this.limit = limit;}

	/**
	 * Set monitor field
	 * @param key Monitor key
	 * @param value Value
	 * @return Previous value
	 */
	public abstract String setMonitor( String key, String value);

	// Set parent
	protected void setParent( Context owner)
	{
		this.parent = owner;
	}

	/**
	 * Set position in HTML file
	 * @param position New position
	 */
	public void setPosition( int position) {this.position = position;}

	/**
	 * Set reference
	 * @param reference
	 */
	public void setReference( String reference) {
		this.reference = reference;
	}
	
	/**
	 * Set rules for context
	 * @param list List of rules
	 */
	public void setRules( List<Rule> list)
	{
		rules = list;
		ruleIndex = 0;
	}

    /**
     * Write data
     *
     * @param source Source for data
     * @param args Write arguments
     */
    public void write(String source, String[] args)
            throws Exception {
        if (source == null) {
            source = this.source;
        }

        for (int i = 0; i < listeners.size(); i++) {
            listeners.get(i).write(source, args);
        }

        if (parent != null) {
            parent.write(source, args);
        }
    }

	// Loaded HTML document as list of elements and texts
	private List<Object> html;

	// Key values
	private Map<String,String> keyValues = new HashMap<String,String>();

	// Limit in HTML structure
	private int limit = -1;

	// Write listeners
	private List<WriteListener> listeners = new ArrayList<WriteListener>();

	// Parent context 
	private Context parent = null;

	// Position in HTML structure
	private int position = 0;

	// Reference
	private String reference;
	
	// Index into rules
	private int ruleIndex;

	// Rules to be executed
	private List<Rule> rules;

	// Source of HTML data
	protected String source;
}
