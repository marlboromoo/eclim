/**
 * Copyright (c) 2005 - 2007
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.eclim.plugin.pdt.command.search;

import org.eclim.Eclim;

import org.eclim.plugin.pdt.Pdt;

import org.junit.Test;

import static org.junit.Assert.*;

public class SearchCommandTest
{
  private static final String TEST_FILE_PHP = "php/search/search.php";

  @Test
  public void searchClass ()
  {
    assertTrue("Project doesn't exist.",
        Eclim.projectExists(Pdt.TEST_PROJECT));

    String result = Eclim.execute(new String[]{
      "php_search", "-n", Pdt.TEST_PROJECT, "-p", "TestA", "-t", "class"
    });

    System.out.println(result);

    String file = Eclim.resolveFile(Pdt.TEST_PROJECT, "php/models.php");
    assertEquals("Wrong Result", file + "|6 col 7|TestA", result);
  }

  @Test
  public void searchMethod ()
  {
    assertTrue("Project doesn't exist.",
        Eclim.projectExists(Pdt.TEST_PROJECT));

    String result = Eclim.execute(new String[]{
      "php_search", "-n", Pdt.TEST_PROJECT, "-p", "methodA1", "-t", "function"
    });

    System.out.println(result);

    String file = Eclim.resolveFile(Pdt.TEST_PROJECT, "php/models.php");
    assertEquals("Wrong Result", file + "|13 col 3|methodA2", result);
  }

  @Test
  public void searchVariable ()
  {
    assertTrue("Project doesn't exist.",
        Eclim.projectExists(Pdt.TEST_PROJECT));

    String result = Eclim.execute(new String[]{
      "php_search", "-n", Pdt.TEST_PROJECT, "-p", "variable1", "-t", "constant"
    });

    System.out.println(result);

    String file = Eclim.resolveFile(Pdt.TEST_PROJECT, "php/models.php");
    assertEquals("Wrong Result", file + "|8 col 3|variable1", result);
  }

  @Test
  public void searchFunction ()
  {
    assertTrue("Project doesn't exist.",
        Eclim.projectExists(Pdt.TEST_PROJECT));

    String result = Eclim.execute(new String[]{
      "php_search", "-n", Pdt.TEST_PROJECT, "-p", "methodA1", "-t", "function"
    });

    System.out.println(result);

    String file = Eclim.resolveFile(Pdt.TEST_PROJECT, "php/models.php");
    assertEquals("Wrong Result", file + "|13 col 3|methodA2", result);
  }

  /**
   * Required for running tests in ant 1.6.5.
   */
  public static junit.framework.Test suite()
  {
    return new junit.framework.JUnit4TestAdapter(SearchCommandTest.class);
  }
}
