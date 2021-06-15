package com.alofmethbin.rintrah.rules;

import org.junit.Test;

public class AttributeTest extends RuleTest {

    @Test
    public void testExecute() throws Exception {
        expectWrite( "AttributeTest", "test", "keywords");
        expectWrite( "AttributeTest", "MrBills", "ALPHABETICAL INDEX");
        expectWrite( "AttributeTest", "AdventureLantern", "u");
    }
}