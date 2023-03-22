package example;


import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

public class ExampleTest {

    @Test
    public void testJoin() {
        assertEquals("1 2 3", Example.join("1", "2", "3"));
    }

}
