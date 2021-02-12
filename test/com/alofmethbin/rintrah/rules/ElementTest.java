package com.alofmethbin.rintrah.rules;

import org.junit.Test;

public class ElementTest extends RuleTest {

    @Test
    public void testExecute() throws Exception {
        expectWrite( "ElementTest", "test", "HEAD");
    }
}
