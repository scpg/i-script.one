---
id: task-1
title: Add parameter "extendedTypes" of type switch
status: To Do
assignee: []
created_date: '2025-09-02 19:40'
labels: []
dependencies: []
---

## Description
The parameter extendedTypes adds the type of the original EXCEL file cell as part of the result file.
* For CSV output files: the Type Information of each column is added to the result
* For JSON output files: the Type Information of each cell will be added to each json object representing the cell, this is the default behaviour. If the parameter "asTable" is also present, then the Type Information will ONLY be added to the JSON collection which represents the first row of the EXCEL
