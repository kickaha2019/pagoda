package com.alofmethbin.rintrah.rules;

import org.junit.Test;

public class TextTest extends RuleTest {

    @Test
    public void testExecute() throws Exception {
        expectWrite( "TextTest", "test", "YESASIA");
        expectWrite( "TextTest", "whitespace", "AGON: Episode 1", "agonshiovitz.html");
        expectWrite( "TextTest", "nbsp", "");
        expectWrite( "TextTest", "xml_encoding", "Home - The Book of Unwritten Tales &ndash; The Fantasy Point &amp; Click Adventure Game");
    }
}