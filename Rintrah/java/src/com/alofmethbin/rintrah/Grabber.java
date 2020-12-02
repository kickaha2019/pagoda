package com.alofmethbin.rintrah;

import java.awt.Color;
import java.awt.Container;
import java.awt.GridBagConstraints;
import java.awt.GridBagLayout;
import java.awt.Insets;
import java.awt.Point;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.StringWriter;
import java.util.prefs.Preferences;

import javax.swing.JButton;
import javax.swing.JComboBox;
import javax.swing.JDialog;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JTextField;

import com.alofmethbin.rintrah.rules.Next;
import com.alofmethbin.rintrah.rules.Rule;
import com.alofmethbin.rintrah.rules.Text;
import com.alofmethbin.rintrah.rules.Url;

/**
 * Grab URLs from a browser to add to scanner
 * script as explicit reference
 * 
 * Command line arguments:
 * 		Filename of script to statements to
 * 		Applescript file to run to get URL from Safari 
 */
public class Grabber extends JFrame {
	private static final long serialVersionUID = 1L;

	// Preferences keys
	public static String MAIN_WIDTH = "main.width", MAIN_HEIGHT = "main.height", MAIN_X="main.x", MAIN_Y="main.y";
	public static String DIALOG_WIDTH = "dialog.width", DIALOG_HEIGHT = "dialog.height", DIALOG_X="dialog.x", DIALOG_Y="dialog.y";

    // Helper class for reading output of shell script
    static class Checker extends Thread {

        Checker(InputStream stream) {
            reader = new BufferedReader(new InputStreamReader(stream));
            this.setDaemon(true);
        }

        public void run() {
            String line;
            try {
                while ((line = reader.readLine()) != null) {
                    writer.write(line + "\n");
                    if (line.startsWith("csh:")) {
                        errors++;
                    }
                }
            } catch (Exception ex) {
                ex.printStackTrace(System.err);
            }
            try {
                reader.close();
            } catch (IOException ioe) {
            }
        }
        private BufferedReader reader;
        public int errors = 0;
        public StringWriter writer = new StringWriter();
    }
	
    // Special rule to save title
    private class GetTitle extends Rule {
    	GetTitle() throws Exception {super( new String [] { "Title"});};
        public void execute(Context context) {
            try {
                title = evaluate(context, 0);
            } catch (Throwable t) {
                error(context, t);
            }
        }
    }
    
	/**
	 * Main program
	 */
	public static void main( String [] args) {
		try {
			Grabber grabber = new Grabber( args[0], args[1], args[2]);
			grabber.setLocation( preferences.getInt( MAIN_X, 10), preferences.getInt( MAIN_Y, 10));
			grabber.setVisible( true);
		} catch (Throwable t) {
			t.printStackTrace();
		}
	}
	
	/**
	 * Constructor
	 * @param filename Name of script file to append URLs grabbed to
	 */
	public Grabber( String cacheDir, String filename, String applescript) throws Exception {
		this.cacheDir = cacheDir;
		
		// Save file to append to
		file = new File( filename);
		if (! file.exists()) {
			throw new FileNotFoundException( filename);
		}
		
		this.applescript = applescript;
		
		// Prepare grab button frame
		this.setTitle( "Grabber");
		this.setDefaultCloseOperation( JFrame.EXIT_ON_CLOSE);
		Container panel = this.getContentPane();
		panel.setLayout( new GridBagLayout());
		
		// Prompt text
		GridBagConstraints gbc = new GridBagConstraints();
		gbc.gridx = 0;
		gbc.gridy = 0;
		gbc.insets = new Insets( 5, 5, 5, 5);
		panel.add( new JLabel( "Go to URL in Safari then"), gbc);
		gbc.gridy = 1;
		panel.add( new JLabel( "press the Grab button"), gbc);
		
		// Grab button
		JButton button = new JButton( "Grab");
		gbc.gridy = 2;
		panel.add( button, gbc);
		
		button.addActionListener( new ActionListener() {
			public void actionPerformed( ActionEvent ae) {
				try {
					grab();
				} catch (Throwable t) {
					t.printStackTrace();
			        JOptionPane.showMessageDialog(null, t.getMessage(), "Grabber", JOptionPane.ERROR_MESSAGE);
				}
			}
		});
		
		// Some initialisation
		urlField.setEditable( false);
		urlField.setBackground( Color.WHITE);
		typeCombo = new JComboBox<String>( new String [] {"Fansite", "Official", "Reference", "Review", "Walkthrough"});
		typeCombo.setSelectedIndex( 0);
		siteField.setText( "*****");
		
		// Record position of window for re-opening
		this.addWindowListener( new WindowAdapter() {
			@Override
			public void windowClosing(WindowEvent arg0) {
				Point p = Grabber.this.getLocationOnScreen();
				preferences.putInt( MAIN_X, p.x);
				preferences.putInt( MAIN_Y, p.y);
				super.windowClosing(arg0);
			}
		});

		this.pack();
	}

	// Grab a URL and add to script file
	private void grab() throws Exception {
		
		// Run Applescript to find URL Safari is looking at
		String url = runApplescript();
		
		// Reuse Scanner code to get Title from this webpage
		title = "";
		Scanner scanner = new Scanner();
		scanner.loadCacheIndex( cacheDir);
		Branch branch = new Branch( new String [] {}); // "GetTitle"});
		branch.rules.add( new Url( new String [] {"\"" + url + "\""}));
		branch.rules.add( new Next( new String [] {"TITLE"}));
		branch.rules.add( new Text( new String [] {"Title"}));
		branch.rules.add( new GetTitle());
		scanner.execute( branch);
		
		// Do dialog containing what we know
		final JDialog dialog = new JDialog();
		dialog.setTitle( "Grabbed URL");
		Container panel = dialog.getContentPane();
		panel.setLayout( new GridBagLayout());
		
		// URL
		GridBagConstraints gbc = new GridBagConstraints();
		gbc.gridx = 0;
		gbc.gridy = 0;
		gbc.insets = new Insets( 5, 5, 5, 5);
		gbc.anchor = GridBagConstraints.WEST;
		panel.add( new JLabel( "URL:"), gbc);
		gbc.gridx = 1;
		urlField.setText( url);
		panel.add( urlField, gbc);
		
		// Title
		gbc.gridx = 0;
		gbc.gridy++;
		panel.add( new JLabel( "Title:"), gbc);
		gbc.gridx = 1;
		titleField.setText( title);
		panel.add( titleField, gbc);
		
		// Site
		gbc.gridx = 0;
		gbc.gridy++;
		panel.add( new JLabel( "Site:"), gbc);
		gbc.gridx = 1;
		panel.add( siteField, gbc);
		
		// Name
		gbc.gridx = 0;
		gbc.gridy++;
		panel.add( new JLabel( "Name:"), gbc);
		gbc.gridx = 1;
		nameField.setText( title);
		panel.add( nameField, gbc);
		
		// Type
		gbc.gridx = 0;
		gbc.gridy++;
		panel.add( new JLabel( "Type:"), gbc);
		gbc.gridx = 1;
		panel.add( typeCombo, gbc);
		
		// Cancel and write buttons
		JPanel buttons = new JPanel();
		
		JButton button = new JButton( "Cancel");
		buttons.add( button);
		
		button.addActionListener( new ActionListener() {
			public void actionPerformed( ActionEvent ae) {
				Point p = dialog.getLocationOnScreen();
				preferences.putInt( DIALOG_X, p.x);
				preferences.putInt( DIALOG_Y, p.y);
				dialog.dispose();
			}
		});
		
		button = new JButton( "Save");
		buttons.add( button);
		
		button.addActionListener( new ActionListener() {
			public void actionPerformed( ActionEvent ae) {
				save();
				Point p = dialog.getLocationOnScreen();
				preferences.putInt( DIALOG_X, p.x);
				preferences.putInt( DIALOG_Y, p.y);
				dialog.dispose();
			}
		});
		
		gbc.gridx = 0;
		gbc.gridy++;
		gbc.gridwidth = 2;
		panel.add( buttons, gbc);

		dialog.setResizable( false);
		dialog.pack();
		dialog.setModal( true);
		dialog.setLocation( preferences.getInt( DIALOG_X, 10), preferences.getInt( DIALOG_Y, 10));
		dialog.setVisible( true);
	}

    // Run Applescript
    private String runApplescript()
            throws Exception 
    {
        // Start shell
        Process process = Runtime.getRuntime().exec( "osascript " + applescript);

        // Start threads to read output and error from shell
        Checker outputChecker = new Checker(process.getInputStream());
        outputChecker.start();

        Checker errorChecker = new Checker(process.getErrorStream());
        errorChecker.start();

        // Wait for shell to finish and check status
        int status = process.waitFor();
        String report = outputChecker.writer.toString() + "\n" +
                errorChecker.writer.toString();

        if (((status != 0) || (outputChecker.errors > 0) ||
                (errorChecker.errors > 0))) 
        {
            System.err.println(report);
            throw new Exception("Error running script");
        }

        return report;
    }

    // Save new URL
    private void save() {
    	try {
    		FileWriter writer = new FileWriter( file, true);
    		writer.write( "\n\t");
    		writer.write( "run Single ");
    		writer.write( "\"" + typeCombo.getSelectedItem() + "\" ");
    		writer.write( "\"" + siteField.getText() + "\" ");
    		writer.write( "\"" + titleField.getText() + "\" ");
    		writer.write( "\"" + nameField.getText() + "\" ");
    		writer.write( "\"" + urlField.getText().trim() + "\" ");
    		writer.close();
    	} catch (Throwable t) {
    		t.printStackTrace();
    	}
    }
    
	// Applescript file
	private String applescript;
	
	// Cache directory
	private String cacheDir;
	
	// Script file
	private File file;
	
	// Field containing name
	private JTextField nameField = new JTextField(40);
	
	// Preferences
	private static Preferences preferences = Preferences.userNodeForPackage( Grabber.class);
	
	// Field containing site
	private JTextField siteField = new JTextField(40);
	
	// Title for URL
	private String title;
	
	// Field containing title
	private JTextField titleField = new JTextField(40);
	
	// List of possible types
	private JComboBox typeCombo;
	
	// Field containing URL
	private JTextField urlField = new JTextField(70);
}
