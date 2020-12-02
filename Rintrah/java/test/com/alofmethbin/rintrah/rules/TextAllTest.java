package com.alofmethbin.rintrah.rules;

import org.junit.Test;

public class TextAllTest extends RuleTest {

    @Test
    public void testExecute() throws Exception {
        expectWrite( "TextTest", "textAll", "Spellforce: The Order of Dawn by Drizzt");
    }
}