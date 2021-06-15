package com.alofmethbin.rintrah;

import com.alofmethbin.rintrah.rules.Rule;
import java.awt.Button;
import java.awt.Dimension;
import java.awt.GridBagConstraints;
import java.awt.GridBagLayout;
import java.awt.Insets;
import java.awt.Label;
import java.awt.Panel;
import java.awt.Toolkit;
import java.awt.Window;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.io.BufferedReader;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.lang.reflect.Constructor;
import java.lang.reflect.InvocationTargetException;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.prefs.Preferences;
import javax.swing.JComboBox;
import javax.swing.JDialog;
import javax.swing.JFrame;

/**
 * Scan webpages for references based on script files.
 * 
 * Scanner command line:
 * 
 * 		<script-directory> <cache-directory> <output-file> <root>
 * 
 * where:
 * 
 * <script-directory> is the directory containing the script files
 * driving the scanning.  These are text files ending in .txt.
 * 
 * <cache-directory> is the directory for the cached HTML of the
 * scanned webpages.
 * 
 * The output of the scan is written to <output-file>
 * 
 * <root> is the optional root to run.
 */
public class Scanner 
{
    // Constants

    private static String FILE = "file", ROOT = "root";
    public static String BRANCH = "Branch", URL = "URL", WRITES = "Writes";
    public static String ERRORS = "Errors", STATUS = "Status";
    // Expected characters
    public static String ALPHABET =
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            + "abcdefghijklmnopqrstuvwxyz"
            + "0123456789"
            + "?!.,/;:'\"{}[]()*&^%$#@~+=-_";
    
    // Cache index 
    private DataOutputStream cacheIndexWriter;

    // Scanner context
    public class ScannerContext extends Context {
        //int nwrites = 0;
        
        @Override
        public void addColumn(String name, String defval) throws Exception {
            if (writes > 0) {
                throw new Exception("Cannot add column after data written");
            }
            columnNames.add(name);
            columnDefaults.add(defval);
        }

        @Override
        public File createTempFile() throws Exception {
            return File.createTempFile("cache", ".html", new File(cacheDirectory));    
        }
        
        @Override
        public Context duplicate() throws Exception {
            Context copy = getContext();
            copy.copy(this);
            return copy;
        }

        @Override
        public void error(String message) {
            Scanner.this.error(message, null);
            dumpStack();
            System.err.println();
        }

        @Override
        public Branch getBranch(String name) throws Exception {
            Object b = roots.get(name);
            if (b != null) {
                return (Branch) b;
            }
            b = branches.get(name);
            if (b != null) {
                return (Branch) b;
            }
            throw new Exception("Branch " + name + " not found");
        }

        @Override
        public File getCachedFile(String url) {
            String name = cacheIndex.get(url);
            if (name == null) {
                return null;
            }
            File file = new File(name);
            if (file.exists()) {
                return file;
            }
            cacheIndex.remove(url);
            return null;
        }

        @Override
        public void log(String message) {
            System.err.println("***** " + message + " [" + Scanner.this.writes + "]");
        }

        @Override
        public Rule makeRule(String name, String[] args, String ref) {
            return Scanner.this.makeRule(name, args, ref);
        }

        @Override
        public void saveCache(String urlText,File cached) throws Exception {
            cacheIndexWriter.writeUTF( urlText);
            cacheIndexWriter.writeUTF( cached.getPath());
            cacheIndexWriter.flush();
        }

        @Override
        public String setMonitor(String key, String value) {
            if (monitor == null) {
                return value;
            }
            String old = monitor.get(key);
            monitor.put(key, value);
            return old;
        }
//
//        @Override
//	public void write( String source, String [] args) throws Exception
//	{
//            super.write(source, args);
//            nwrites ++;
//	}
    }

    /**
     * Main program
     *
     * @param args
     */
    public static void main(String[] args) {
        try {
            if (! (new Scanner()).run(args)) {
                System.exit(1);
            }
        } catch (Throwable t) {
            t.printStackTrace(System.err);
            System.exit(1);
        }
    }

    // Handle fatal error
    private static void abort(String message) {
        System.err.println("***** " + message);
        System.exit(1);
    }

	// Centre frame on screen
	private void centre( Window frame)
	{
		Dimension screen = Toolkit.getDefaultToolkit().getScreenSize();
		double x = (screen.getWidth() - frame.getWidth()) / 2;
		double y = (screen.getHeight() - frame.getHeight()) / 2;
		frame.setLocation( (int) x, (int) y);
	}

    // Choose root rules to execute
    private String choose() {
        if (roots.size() < 1) {
            abort("No roots found");
        }
        populateFileCombo();
        populateRootCombo();

        final JDialog dialog = new JDialog();
        dialog.getContentPane().setLayout(new GridBagLayout());
        dialog.setTitle("Scanner launcher");

        GridBagConstraints gbc = new GridBagConstraints();

        // Add the file combo box
        gbc.gridx = 0;
        gbc.gridy = 0;
        gbc.gridwidth = 1;
        gbc.insets = new Insets(5, 5, 5, 5);
        gbc.anchor = GridBagConstraints.WEST;
        dialog.getContentPane().add(new Label("File:"), gbc);
        gbc.gridx = 1;
        dialog.getContentPane().add(fileCombo, gbc);

        // Add the root combo box
        gbc.gridx = 0;
        gbc.gridy = 1;
        dialog.getContentPane().add(new Label("Root:"), gbc);
        gbc.gridx = 1;
        dialog.getContentPane().add(rootCombo, gbc);

        // Refresh root combo on changing file
        fileCombo.addActionListener(new ActionListener() {
            @Override
            public void actionPerformed(ActionEvent e) {
                populateRootCombo();
            }
        });

        // Add the OK and Cancel buttons
        Panel buttons = new Panel();
        buttons.add(ok);
        buttons.add(cancel);
        gbc.gridy = 2;
        gbc.gridx = 0;
        gbc.gridwidth = 2;
        gbc.anchor = GridBagConstraints.CENTER;
        dialog.getContentPane().add(buttons, gbc);

        // Handle click on OK button
        ok.addActionListener(new ActionListener() {
            @Override
            public void actionPerformed(ActionEvent ae) {
                preferences.put(FILE, (String) fileCombo.getSelectedItem());
                preferences.put(ROOT, (String) rootCombo.getSelectedItem());
                synchronized (dialog) {
                    dialog.dispose();
                    dialog.notifyAll();
                }
            }
        });

        // Handle click on Cancel button
        cancel.addActionListener(new ActionListener() {
            @Override
            public void actionPerformed(ActionEvent ae) {
                System.exit(0);
            }
        });

        // On request to close window shut everything down
        dialog.setDefaultCloseOperation(JFrame.DO_NOTHING_ON_CLOSE);

        //this.setUndecorated( true);
        dialog.setResizable(false);
        dialog.setSize(300, 150);
        centre(dialog);
        //this.setCursor( new Cursor( Cursor.WAIT_CURSOR));

        // Wait for user input
        synchronized (dialog) {
            dialog.setVisible(true);
            try {
                dialog.wait();
            } catch (InterruptedException ie) {
                System.exit(1);
            }
        }

        // Return chosen root
        String name = fileCombo.getSelectedItem() + "/" + rootCombo.getSelectedItem();
        return name;
    }

    // Dump cache index
//    private void dumpCacheIndex() throws Exception {
//        BufferedWriter writer1 = new BufferedWriter( new FileWriter( new File(cacheDirectory, "index.txt")));
//        for (Iterator<Map.Entry<String, String>> i = cacheIndex.entrySet().iterator(); i.hasNext();) {
//            Map.Entry<String, String> e = i.next();
//            writer1.write(e.getKey());
//            writer1.write("\t");
//            writer1.write(e.getValue());
//            writer1.write("\n");
//        }
//        writer1.close();
//    }

    // Report error
    public void error(String message, String reference) {
        System.err.println("***** " + message);
        if (reference != null) {
            System.err.println("***** " + reference);
        }
        errorCount++;
        if (monitor != null) {
            monitor.put(ERRORS, Integer.toString(errorCount));
        }
    }

    // Report traceback
    public void error(Throwable thrown, String reference) {
        error(thrown.getMessage(), reference);
        //thrown.printStackTrace(System.err);
    }

    // Execute root rule
    private void execute(String root, String outputFilename, boolean gui) {
        try {
            final Scanner scanner = this;
            writer = new OutputStreamWriter( new FileOutputStream( outputFilename)); // , "UTF8");

            if (gui) {
                monitor = new ScannerMonitor();
                monitor.put(ERRORS, "0");
                monitor.put(STATUS, "Running");
                centre(monitor);
                monitor.setVisible(true);
            }

            try {
            	execute( root, new WriteListener() {
                    @Override
                    public void write(String source, String[] args) throws Exception {
                        scanner.write(source, args);
                    }
                });
                if ( gui) {
                    monitor.put(STATUS, "Finished");
                }
            } finally {
                flush();
            }
        } catch (Throwable t) {
            if ( gui ) {
                monitor.put(STATUS, "Aborted");
            }
            error(t, root);
        }
    }

    /**
     * Execute given branch
     */
    public void execute(Branch branch) throws Exception {
        Context context = getContext();
        branch.prepare(context, new String[]{}).execute();
    }

    /**
     * Execute given branch
     */
    protected void execute(String branchName, WriteListener listener) throws Exception {
        Branch branch = roots.get( branchName);
        if (branch == null) {
            throw new Exception( "Branch [" + branchName + "] not found");
        }
        Context context = getContext();
        context.addWriteListener(listener);
        context.log( "Starting " + branchName);
        branch.prepare( context, new String[]{}).execute();
        context.log( "Finished " + branchName);
        if (errorCount > 0) {context.log( errorCount + " errors");}
    }

	/**
	 * Flush writes
	 */
	public void flush() throws Exception {
		writer.close();
	}
	
	/**
	 * Get new context
	 * @return New context
	 */
	public Context getContext() {return new ScannerContext();}
	
    // Load script file
    private void load(File script) throws Exception {
        BufferedReader reader = new BufferedReader(new FileReader(script));
        String scriptName = script.getName();
        scriptName = scriptName.substring(0, scriptName.length() - 4);
        load( scriptName, reader);
    }
    
    // Load script 
    protected void load( String scriptName, BufferedReader reader) throws Exception {
        String line;
        Set<String> seen = new HashSet<String>();
        Branch branch = null;
        int lineNumber = 0;

        while ((line = reader.readLine()) != null) {
            lineNumber++;
            String ref = "at line " + lineNumber + " of file " + scriptName;
            String[] tokens = parse(ref, line);

            if ((tokens != null) && (tokens.length > 0)) {
                String name = tokens[0];

                // Special metarules
                if ("root".equals(name.toLowerCase())) {
                    if (tokens.length < 2) {
                        error("Bad root rule", ref);
                        continue;
                    }
                    branch = new Branch(Scanner.slice(tokens, 2));
                    if (seen.contains(tokens[1])) {
                        error("Duplicate root / branch name", ref);
                        continue;
                    }
                    seen.add(tokens[1]);
                    roots.put(scriptName + "/" + tokens[1], branch);
                } else if ("branch".equals(name.toLowerCase())) {
                    if (tokens.length < 2) {
                        error("Bad branch rule", ref);
                        continue;
                    }
                    branch = new Branch(Scanner.slice(tokens, 2));
                    if (seen.contains(tokens[1])) {
                        error("Duplicate root / branch name", ref);
                        continue;
                    }
                    seen.add(tokens[1]);
                    branches.put(scriptName + "/" + tokens[1], branch);
                } else {
                    String[] args = Scanner.slice(tokens, 1);
                    Rule rule = makeRule(name, args, ref);

                    if (rule != null) {
                        rule.setReference(ref);
                        rule.setScript(scriptName);

                        if (branch == null) {
                            error("No branch or root defined", ref);
                        } else {
                            branch.rules.add(rule);
                        }
                    }
                }
            }
        }

        reader.close();
        if (errorCount > 0) {
            throw new Exception(errorCount + " errors loading " + scriptName);
        }
    }

    // Load cache index
    public void loadCacheIndex(String dir) throws Exception {
        cacheDirectory = dir;
        cacheIndex = new HashMap<>();
        DataInputStream dis = null;

        // Blow away any cached HTML files older than 1000 days
        File[] cached = (new File(dir)).listFiles();
        for (File cached1 : cached) {
            if (cached1.getName().endsWith(".html")) {
                if (older(cached1, 1000)) {
                    if (!cached1.delete()) {
                        throw new Exception("Unable to delete " + cached1.getPath());
                    }
                }
            }
        }

        // Load the cache index
        try {
            dis = new DataInputStream(new FileInputStream(new File(dir, "index.dat")));
            dis.readInt(); // Originally count now ignored
            while (dis.available() > 0) {
                String url = dis.readUTF();
                String name = dis.readUTF();
                if ( (new File( name)).exists() ) {
                    cacheIndex.put(url, name);
                }
            }
        } catch (Exception ex) {
            System.out.println( "***** Error loading cache index");
        } finally {
            if (dis != null) {
                dis.close();
            }
            saveCacheIndex();
        }
    }

	// Make a rule
	protected Rule makeRule( String name, String [] args, String ref)
	{
		try {
			name = Character.toUpperCase( name.charAt( 0)) + name.substring( 1);
			Class<?> ruleClass = Class.forName( "com.alofmethbin.rintrah.rules." + name);
			Constructor<?> constr = ruleClass.getConstructor( new Class [] {args.getClass()});
			return (Rule) constr.newInstance( new Object [] {args});}
		catch (Throwable t) {
			if (t instanceof InvocationTargetException) {
				t = t.getCause();
			}
			error( t, ref);
			return null;
		}
	}

	/**
	 * Check for file being older than N days
	 * @param file File to check
	 * @param days Max days
	 * @return true iff older or null file
	 */
	public static boolean older( File file, int days)
	{
		return (file == null) || ((file.lastModified() + days * 1000L * 60L * 60L * 24L) < now);
	}

    // Parse line into tokens
    private String[] parse(String ref, String line) {
        List<String> tokens = new ArrayList<String>();
        StringBuilder b = new StringBuilder();
        boolean quoted = false;

        for (int i = 0; i < line.length(); i++) {
            char ch = line.charAt(i);
            if (quoted) {
                b.append(ch);
                if (ch == '"') {
                    quoted = false;
                    tokens.add(b.toString());
                    b.setLength(0);
                }
            } else if (ch == '+') {
                if (b.length() > 0) {
                    tokens.add(b.toString());
                    b.setLength(0);
                }
                tokens.add("+");
            } else if (ch == '#') {
                break;
            } else if (Character.isWhitespace(ch)) {
                if (b.length() > 0) {
                    tokens.add(b.toString());
                    b.setLength(0);
                }
                continue;
            } else if (ch == '"') {
                if (b.length() > 0) {
                    error("", ref);
                    return null;
                }
                b.append(ch);
                quoted = true;
            } else {
                b.append(ch);
            }
        }

        if (quoted) {
            error("Unbalanced \"s in [" + line + "]", ref);
            return null;
        }

        if (b.length() > 0) {
            tokens.add(b.toString());
        }

        String[] result = new String[tokens.size()];
        for (int i = 0; i < result.length; i++) {
            result[ i] = tokens.get(i);
        }

        return result;
    }

	// Populate file combo
	private void populateFileCombo()
	{
		Set<String> files = new TreeSet<String>();

		for (Iterator<String> i = roots.keySet().iterator(); i.hasNext();) {
			String name = i.next();
			files.add( name.substring( 0, name.indexOf( '/')));
		}

		for (Iterator<String> i = files.iterator(); i.hasNext();) {
			fileCombo.addItem( i.next());
		}

		String defval = (String) fileCombo.getItemAt( 0);
		String choice = preferences.get( FILE, defval);

		if (! files.contains( choice)) {choice = defval;}
		fileCombo.setSelectedItem( choice);
	}

	// Populate root combo
	private void populateRootCombo()
	{
		Set<String> poss = new TreeSet<String>();
		String stem = fileCombo.getSelectedItem() + "/";

		for (Iterator<String> i = roots.keySet().iterator(); i.hasNext();) {
			String name = i.next();
			if ( name.startsWith( stem) ) {
				poss.add( name.substring( stem.length()));
			}
		}

		rootCombo.removeAllItems();
		for (Iterator<String> i = poss.iterator(); i.hasNext();) {
			rootCombo.addItem( i.next());
		}

		String defval = (String) rootCombo.getItemAt( 0);
		String choice = preferences.get( ROOT, defval);

		if (! poss.contains( choice)) {choice = defval;}
		rootCombo.setSelectedItem( choice);
	}

    /**
     * Run the scanner
     * @param args
     * @return true iff no errors
     * @throws Exception
     */
    public boolean run(String[] args) throws Exception {
        String root;

        // Load cache index
        this.loadCacheIndex(args[1]);

        // Load the rule chains in the script files
        File[] scripts = (new File(args[0])).listFiles();
        for (int i = 0; i < scripts.length; i++) {
            if (scripts[i].getName().endsWith(".txt")) {
                load(scripts[i]);
            }
        }

        // Choose root to execute if not specified on command line
        boolean gui = (args.length <= 3);
        root = gui ? choose() : args[3];

        // Execute from root
        execute(root, args[2], gui);
        return errorCount == 0;
    }

    // Save cache index
    private void saveCacheIndex() throws Exception {
        cacheIndexWriter = new DataOutputStream(new FileOutputStream(new File(cacheDirectory, "index.dat")));
        cacheIndexWriter.writeInt(cacheIndex.size());
        for (Iterator<Map.Entry<String, String>> i = cacheIndex.entrySet().iterator(); i.hasNext();) {
            Map.Entry<String, String> e = i.next();
            cacheIndexWriter.writeUTF(e.getKey());
            cacheIndexWriter.writeUTF(e.getValue());
        }
        cacheIndexWriter.flush();
        //System.out.println( "*** Cache index saved");
    }

    // Return slice of String array
    private static String[] slice(String[] array, int offset) {
        String[] sliced = new String[array.length - offset];

        for (int i = 0; i < sliced.length; i++) {
            sliced[i] = array[i + offset];
        }

        return sliced;
    }

    /**
     * Split line by tabs
     * @param line Line to split
     * @return Line elements
     */
    public static String[] split(String line) {
        int tabs = 0;

        for (int i = 0; i < line.length(); i++) {
            if (line.charAt(i) == '\t') {
                tabs++;
            }
        }

        String[] parts = new String[tabs + 1];

        StringBuilder b = new StringBuilder();
        tabs = 0;

        for (int i = 0; i < line.length(); i++) {
            char ch = line.charAt(i);
            if (ch == '\t') {
                parts[tabs++] = b.toString();
                b.setLength(0);
            } else if (ch != '\n') {
                b.append(ch);
            }
        }

        parts[tabs] = b.toString();
        return parts;
    }

    /**
     * Replace weird characters with ?s
     * @param text
     * @return Text to process
     */
    private static String trashSpecialCharacters(String text) {
        StringBuilder b = new StringBuilder();
        for (int i = 0; i < text.length(); i++) {
            char ch = text.charAt(i);
            if (CheckChars.EXPECTED.indexOf(ch) < 0) {
                b.append('?');
            } else {
                b.append(ch);
            }
        }
        return b.toString();
    }

    /**
     * Write data
     *
     * @param source Source for data
     * @param args Write call arguments
     */
    protected void write(String source, String[] args) throws Exception {
        boolean first = (urlField == -1);

        // Find field containing URL on first write
        if (first) {
            urlField = -2;

            for (int i = 0; i < columnNames.size(); i++) {
                if (URL.equalsIgnoreCase(columnNames.get(i))) {
                    urlField = i;
                }
            }

            if (urlField < 0) {
                for (int i = 0; i < args.length; i++) {
                    if (args[i].startsWith("http:")) {
                        urlField = i;
                    }
                }
            }
        }

        // Check for URL already written on subsequent records
        if ((urlField >= 0) && (args.length > urlField)) {
            if (!urlsWritten.add(args[urlField])) {
                return;
            }
        }

        // On first write output the column names first prefixed by the
        // special id column
        if (first) {
            writer.write("id");

            for (int i = 0; i < columnNames.size(); i++) {
                writer.write("\t");
                writer.write(columnNames.get(i).toString());
            }

            writer.write("\n");
        }

        // Write out record
        writer.write(Integer.toString(writes));

        for (int i = 0; i < args.length; i++) {
            writer.write("\t");
            writer.write(Scanner.trashSpecialCharacters(args[i]));
        }

        // Append column defaults for missing columns
        for (int i = args.length; i < columnNames.size(); i++) {
            writer.write("\t");
            writer.write(columnDefaults.get(i).toString());
        }

        writer.write("\n");

        // Update monitor
        ++writes;
        if (monitor != null) {
            monitor.put(WRITES, Integer.toString(writes));
        }
    }

	// Tables of branch rule chains keyed by script file / branch name
	private Map<String,Branch> branches = new HashMap<String,Branch>();

	// Cache directory
	private String cacheDirectory;

	// Cache index 
	private Map<String,String> cacheIndex = null;

	// Cancel button
	private Button cancel = new Button( "Cancel");

	// Defaults for columns
	private List<String> columnDefaults = new ArrayList<String>();

	// Names of columns
	private List<String> columnNames = new ArrayList<String>();

	// Error count
	private int errorCount = 0;

	// File combo
	private JComboBox<String> fileCombo = new JComboBox<>();

	// Monitor
	private ScannerMonitor monitor;

	// Current time
	private static long now = (new Date()).getTime();

	// OK button
	private Button ok = new Button( "OK");

	// Preferences
	private Preferences preferences = Preferences.userNodeForPackage( Scanner.class);

	// Root combo
	private JComboBox<String> rootCombo = new JComboBox<>();

	// Tables of root rule chains keyed by script file / root name
	private Map<String,Branch> roots = new HashMap<String,Branch>();
        
	// Index of URL field on output
	private int urlField = -1;

	// URLs written (set used to eliminate duplicates)
	private Set<String> urlsWritten = new HashSet<String>();

	// Writer for output
	protected Writer writer;

	// Number of records written
	private int writes = 0;
}
