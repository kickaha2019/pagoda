package com.alofmethbin.rintrah.rules;

import org.junit.Test;
import static org.junit.Assert.*;

public class WriteTest extends RuleTest {

    @Test
    public void testExecute() throws Exception {
        expectWrite( "WriteTest", "once", "Zaphod");
        expectWrite( "WriteTest", "twice", "Beyond", "Time");
    }

	@Test
    public void testTrim() {
        assertEquals( "The Wizard", Write.trim( "(The) Wizard"));
        assertEquals( "The Wizard", Write.trim( " The Wizard "));
        assertEquals( "The Wizard", Write.trim( "“The Wizard”"));
    }
}