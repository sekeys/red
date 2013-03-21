Red [
	Title:	"Red console"
	Author: ["Nenad Rakocevic" "Kaj de Vos"]
	File: 	%console.red
	Tabs: 	4
	Rights: "Copyright (C) 2012-2013 Nenad Rakocevic. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/dockimbel/Red/blob/master/BSL-License.txt
	}
]

#system-global [
	#either OS = 'Windows [
		#import [
			"kernel32.dll" stdcall [
				AttachConsole: 	 "AttachConsole" [
					processID		[integer!]
					return:			[integer!]
				]
				SetConsoleTitle: "SetConsoleTitleA" [
					title			[c-string!]
					return:			[integer!]
				]
				ReadConsole: 	 "ReadConsoleA" [
					consoleInput	[integer!]
					buffer			[byte-ptr!]
					charsToRead		[integer!]
					numberOfChars	[int-ptr!]
					inputControl	[int-ptr!]
					return:			[integer!]
				]
			]
		]
	][
		#switch OS [
			MacOSX [  ; TODO: check this
				#define ReadLine-library "libreadline.dylib"
				#define History-library  "libhistory.dylib"
			]
			#default [
				#define ReadLine-library "libreadline.so.6"
				#define History-library  "libhistory.so.6"
			]
		]
		#import [
			ReadLine-library cdecl [
				read-line: "readline" [  ; Read a line from the console.
					prompt			[c-string!]
					return:			[c-string!]
				]
			]
			History-library cdecl [
				add-history: "add_history" [  ; Add line to the history.
					line			[c-string!]
				]
			]
		]
	]
]

init-console: routine [
	str [string!]
	/local
		ret
][
	#either OS = 'Windows [
		;ret: AttachConsole -1
		;if zero? ret [print-line "ReadConsole failed!" halt]
		
		ret: SetConsoleTitle as c-string! string/rs-head str
		if zero? ret [print-line "ReadConsole failed!" halt]
	][
		print-line as-c-string string/rs-head str
	]
]

input: routine [
	/local
		len ret str buffer line
][
	#either OS = 'Windows [
		len: 0
		buffer: allocate 128
		ret: ReadConsole stdin buffer 127 :len null
		if zero? ret [print-line "ReadConsole failed!" halt]
		len: len + 1
		buffer/len: null-byte
		str: string/load as c-string! buffer len
;		free buffer
	][
		line: read-line ""
		if line = null [halt]  ; EOF

		add-history line

		str: string/load line  1 + length? line
;		free as byte-ptr! line
	]
	SET_RETURN(str)
]

count-delimiters: function [
	buffer	[string!]
	return: [block!]
][
	list: copy [0 0]
	c: none
	
	foreach c buffer [
		switch c [
			#"[" [list/1: list/1 + 1]
			#"]" [list/1: list/1 - 1]
			#"{" [list/2: list/2 + 1]
			#"}" [list/2: list/2 - 1]
		]
	]
	list
]

clear-CR: function [str [string!]][
	if crlf = pos: skip tail str -2 [remove pos]
]

do-console: function [][
	buffer: make string! 10000
	prompt: red-prompt: "red>> "
	mode:  'mono
	
	switch-mode: [
		mode: case [
			cnt/1 > 0 ['block]
			cnt/2 > 0 ['string]
			'else 	  [
				prompt: red-prompt
				do eval
				'mono
			]
		]
		prompt: switch mode [
			block  ["[^-"]
			string ["{^-"]
			mono   [red-prompt]
		]
	]
	
	eval: [
		code: load/all buffer
		unless tail? code [
			set/any 'result do code
			unless unset? :result [
				print ["==" mold :result]				;@@ use mold/part
			]
		]
		clear buffer
	]

	while [true][
		prin prompt
		
		unless tail? line: input [
			if crlf = pos: skip tail line -2 [remove pos]	;-- clear extra CR (Windows)
			
			append buffer line
			cnt: count-delimiters buffer
			
			switch mode [
				block  [if cnt/1 <= 0 [do switch-mode]]
				string [if cnt/2 <= 0 [do switch-mode]]
				mono   [do either any [cnt/1 > 0 cnt/2 > 0][switch-mode][eval]]
			]
		]
	]
]

init-console "Red Console (Xmas demo edition!)"

print {
-=== Red Console alpha version ===-
(only Latin-1 input supported)
}

do-console
