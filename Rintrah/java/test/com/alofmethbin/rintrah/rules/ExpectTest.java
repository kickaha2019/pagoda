package com.alofmethbin.rintrah.rules;

import org.junit.Test;

public class ExpectTest extends RuleTest {

    @Test
    public void testExecute() throws Exception {
        expectError( "ExpectTest", "find", null);
        expectError( "ExpectTest", "not_find", "Expected write [Quoth the Raven nevermore] not seen");
    }
}
