/**
 * Copyright (C) 2005 - 2011  Eric Van Dewoestine
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
package org.eclim.eclipse.jface.text.contentassist;

import org.eclipse.jface.text.ITextViewer;

import org.eclipse.jface.text.contentassist.ICompletionListener;
import org.eclipse.jface.text.contentassist.IContentAssistProcessor;
import org.eclipse.jface.text.contentassist.IContentAssistant;
import org.eclipse.jface.text.contentassist.IContentAssistantExtension2;

/**
 * Dummy implementation of IContentAssistantExtension2.
 *
 * @author Eric Van Dewoestine
 */
public class DummyContentAssistantExtension2
  implements IContentAssistant, IContentAssistantExtension2
{
// IContentAssistant

  /**
   * {@inheritDoc}
   */
  public void install(ITextViewer textViewer)
  {
  }

  /**
   * {@inheritDoc}
   */
  public void uninstall()
  {
  }

  /**
   * {@inheritDoc}
   */
  public String showPossibleCompletions()
  {
    return null;
  }

  /**
   * {@inheritDoc}
   */
  public String showContextInformation()
  {
    return null;
  }

  /**
   * {@inheritDoc}
   */
  public IContentAssistProcessor getContentAssistProcessor(String contentType)
  {
    return null;
  }

// IContentAssistantExtension2

  /**
   * {@inheritDoc}
   */
  public void addCompletionListener(ICompletionListener listener)
  {
  }

  /**
   * {@inheritDoc}
   */
  public void removeCompletionListener(ICompletionListener listener)
  {
  }

  /**
   * {@inheritDoc}
   */
  public void setRepeatedInvocationMode(boolean cycling)
  {
  }

  /**
   * {@inheritDoc}
   */
  public void setShowEmptyList(boolean showEmpty)
  {
  }

  /**
   * {@inheritDoc}
   */
  public void setStatusLineVisible(boolean show)
  {
  }

  /**
   * {@inheritDoc}
   */
  public void setStatusMessage(String message)
  {
  }

  /**
   * {@inheritDoc}
   */
  public void setEmptyMessage(String message)
  {
  }
}
