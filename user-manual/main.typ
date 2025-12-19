#set text(
  //font: "Open Sans",
  size: 11pt
)

#show link: set text(fill: blue)
#show ref: set text(fill: blue)

#set document(
  title: [Hardware Build System - User Manual],
  author: "Michał Kruszewski"
)

#import "vars.typ"

#include "cover.typ"

#set page(
  numbering: "1",
  header: [
    #text(9pt)[Rev. #vars.rev]
    #h(1fr)
    #text(9pt)[HBS User Manual]
  ]
)

#set heading(
  numbering: "1.1.1"
)

#set page(footer: {
  set text(9pt)
  align(center, context counter(page).display())
})

#set par(justify: true)

#outline(indent: 1em)


//#set raw(syntaxes: "fbdl.sublime-syntax")

#include "participants.typ"
#include "glossary.typ"
#include "overview.typ"
#include "architecture.typ"
#include "commands.typ"
#include "tcl-tips.typ"
