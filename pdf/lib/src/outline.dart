/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

part of pdf;

enum PdfOutlineMode {
  /// When jumping to the destination, display the whole page
  fitpage,

  /// When jumping to the destination, display the specified region
  fitrect
}

class PdfOutline extends PdfObject {
  /// This holds any outlines below us
  List<PdfOutline> outlines = [];

  /// For subentries, this points to it's parent outline
  PdfOutline parent;

  /// This is this outlines Title
  final String title;

  /// The destination page
  PdfPage dest;

  /// The region on the destination page
  final PdfRect rect;

  /// How the destination is handled
  PdfOutlineMode destMode = PdfOutlineMode.fitpage;

  /// Constructs a Pdf Outline object. When selected, the specified region
  /// is displayed.
  ///
  /// @param title Title of the outline
  /// @param dest The destination page
  /// @param rect coordinate
  PdfOutline(PdfDocument pdfDocument, {this.title, this.dest, this.rect})
      : super(pdfDocument, "/Outlines");

  /// This method creates an outline, and attaches it to this one.
  /// When the outline is selected, the supplied region is displayed.
  ///
  /// Note: the coordiates are in User space. They are converted to User
  /// space.
  ///
  /// This allows you to have an outline for say a Chapter,
  /// then under the chapter, one for each section. You are not really
  /// limited on how deep you go, but it's best not to go below say 6 levels,
  /// for the reader's sake.
  ///
  /// @param title Title of the outline
  /// @param dest The destination page
  /// @param x coordinate of region in User space
  /// @param y coordinate of region in User space
  /// @param w width of region in User space
  /// @param h height of region in User space
  /// @return [PdfOutline] object created, for creating sub-outlines
  PdfOutline add({String title, PdfPage dest, PdfRect rect}) {
    PdfOutline outline =
        PdfOutline(pdfDocument, title: title, dest: dest, rect: rect);
    // Tell the outline of ourselves
    outline.parent = this;
    return outline;
  }

  /// @param os OutputStream to send the object to
  @override
  void prepare() {
    super.prepare();

    // These are for kids only
    if (parent != null) {
      params["/Title"] = PdfStream.string(title);
      var dests = List<PdfStream>();
      dests.add(dest.ref());

      if (destMode == PdfOutlineMode.fitpage) {
        dests.add(PdfStream.string("/Fit"));
      } else {
        dests.add(
            PdfStream.string("/FitR ${rect.l} ${rect.b} ${rect.r} ${rect.t}"));
      }
      params["/Parent"] = parent.ref();
      params["/Dest"] = PdfStream.array(dests);

      // were a decendent, so by default we are closed. Find out how many
      // entries are below us
      int c = descendants();
      if (c > 0) {
        params["/Count"] = PdfStream.intNum(-c);
      }

      int index = parent.getIndex(this);
      if (index > 0) {
        // Now if were not the first, then we have a /Prev node
        params["/Prev"] = parent.getNode(index - 1).ref();
      }

      if (index < parent.getLast()) {
        // We have a /Next node
        params["/Next"] = parent.getNode(index + 1).ref();
      }
    } else {
      // the number of outlines in this document
      // were the top level node, so all are open by default
      params["/Count"] = PdfStream.intNum(outlines.length);
    }

    // These only valid if we have children
    if (outlines.length > 0) {
      // the number of the first outline in list
      params["/First"] = outlines[0].ref();

      // the number of the last outline in list
      params["/Last"] = outlines[outlines.length - 1].ref();
    }
  }

  /// This is called by children to find their position in this outlines
  /// tree.
  ///
  /// @param outline [PdfOutline] to search for
  /// @return index within Vector
  int getIndex(PdfOutline outline) => outlines.indexOf(outline);

  /// Returns the last index in this outline
  /// @return last index in outline
  int getLast() => outlines.length - 1;

  /// Returns the outline at a specified position.
  /// @param i index
  /// @return the node at index i
  PdfOutline getNode(int i) => outlines[i];

  /// Returns the total number of descendants below this one.
  /// @return the number of descendants below this one
  int descendants() {
    int c = outlines.length; // initially the number of kids

    // now call each one for their descendants
    for (PdfOutline o in outlines) {
      c += o.descendants();
    }

    return c;
  }
}
