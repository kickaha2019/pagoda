package com.alofmethbin.rintrah.rules;

import org.junit.Test;

public class IfTest extends RuleTest {

    @Test
    public void testExecute() throws Exception {
        expectWrite( "IfTest", "true", "Girl");
        expectWrite( "IfTest", "false", "Boy");
    }
}
