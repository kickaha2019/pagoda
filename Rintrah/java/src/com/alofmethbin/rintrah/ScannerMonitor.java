package com.alofmethbin.rintrah;

import java.awt.*;
import javax.swing.*;
import javax.swing.text.*;

/**
 * Monitor frame for spider
 */
public class ScannerMonitor extends JFrame
{
	private static final long serialVersionUID = 1L;

/**
   * Constructor
   */
  public ScannerMonitor()
  {
    getContentPane().setLayout( new GridBagLayout());

    addField( Scanner.BRANCH, new JTextField(30));
    addField( Scanner.URL, new JTextArea( 5, 40));
    addField( Scanner.WRITES, new JTextField(6));
    addField( Scanner.ERRORS, new JTextField(6));
    addField( Scanner.STATUS, new JTextField(10));
 
    this.setTitle( "Scanner monitor");
    this.setDefaultCloseOperation( JFrame.EXIT_ON_CLOSE);
    this.pack();
  }

  // Add a field
  private void addField( String label, JTextComponent field)
  {
    int row = getContentPane().getComponentCount() / 2;
    GridBagConstraints gbc = new GridBagConstraints();
    gbc.gridy = row;
    gbc.insets = new Insets( 10, 10, 10, 10);
    gbc.anchor = GridBagConstraints.WEST;
    getContentPane().add( new JLabel( label + ":"), gbc);
    field.setEditable( false);
    field.setBackground( Color.WHITE);
    field.setForeground( Color.BLACK);
    gbc.gridx = 1;
    gbc.gridwidth = 1;
    getContentPane().add( field, gbc);
  }

  // Add a text area
  private void addField( String label, JTextArea field)
  {
    addField( label, (JTextComponent) field);
    field.setLineWrap( true);
  }

  // Get a value
  public String get( String key)
  {
    for (int i = 0; i < getContentPane().getComponentCount(); i += 2) {
      JLabel label = (JLabel) getContentPane().getComponent( i);
      if ( (key + ":").equals( label.getText()) ) {
        JTextComponent field = (JTextComponent) getContentPane().getComponent( i+1);
        return field.getText();
      }
    }

    return "";
  }

    // Set a value
    public void put(String key, String value) {
        try {
            for (int i = 0; i < getContentPane().getComponentCount(); i += 2) {
                JLabel label = (JLabel) getContentPane().getComponent(i);
                if ((key + ":").equals(label.getText())) {
                    JTextComponent field = (JTextComponent) getContentPane().getComponent(i + 1);
                    field.setText(value);
                }
            }
        } catch (Throwable t) {
            t.printStackTrace();
        }
    }
}
