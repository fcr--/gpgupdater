#!/bin/sh
# \
exec tclsh8.5 "$0" "$@"

# This is the GPGUpdater by Francisco Castro <fcr@adinet.com.uy>.
#
# GPGUpdater is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# GPGUpdater is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with GPGUpdater.  If not, see <http://www.gnu.org/licenses/>.

package require Tk
package require Ttk
package require http
package require control

::ttk::setTheme clam

# Lista de servidores habilitados (de aquí se obtiene la lista de
# servidores por omisión cuando no hay archivo de configuración de
# servidores):
set lista_de_servidores {
  hkp://dir2.es.net
  hkp://esperanza.ubuntu.com
  hkp://gozer.rediris.es
  hkp://gpg-keyserver.de
  hkp://ice.mudshark.org
  hkp://keyring.debian.org
  hkp://keyserver.cais.rnp.br
  hkp://keyserver.fabbione.net
  hkp://keyserver.ganneff.de
  hkp://keyserver.hadiko.de
  hkp://keyserver.kim-minh.com
  hkp://keyserver.linux.it
  hkp://keyserver.mine.nu
  hkp://keyserver.noreply.org
  hkp://keyserver.oeg.com.au
  hkp://keyserver.pgp.com
  hkp://keyserver.pramberger.at
  hkp://keyserver.progman.us
  hkp://keyserver.rootbash.com
  hkp://keyserv.nic.se
  hkp://keys.gnupg.net
  hkp://keys.iif.hu
  hkp://keys.nayr.net
  hkp://keys.thoma.cc
  hkp://kies.mcbone.net
  hkp://lorien.prato.linux.it
  hkp://mcc.mycomputercop.com
  hkp://minbari.maluska.de
  hkp://minsky.surfnet.nl
  hkp://nicpgp2.nic.ad.jp
  hkp://pgp.eteo.mondragon.edu
  hkp://pgpkeys.logintas.ch
  hkp://pgpkeys.pca.dfn.de
  hkp://pgp.mit.edu
  hkp://pgp.sjbcom.com
  hkp://pgp.srv.ualberta.ca
  hkp://pgp.uk.demon.net
  hkp://pgp.uni-mainz.de
  hkp://pgp.zdv.uni-mainz.de
  hkp://pks.aaiedu.hr
  hkp://pks.gpg.cz
  hkp://pks.mtholyoke.edu
  hkp://pool.sks-keyservers.net
  hkp://r24-live.duf.hu
  hkp://rex.citrin.ch
  hkp://search.keyserver.net
  hkp://sks.ms.mff.cuni.cz
  hkp://sks.pkqs.net
  hkp://stinkfoot.org
  hkp://subkeys.pgp.net
  hkp://the.earth.li
  hkp://wwwkeys.ch.pgp.net
  hkp://wwwkeys.cz.pgp.net
  hkp://wwwkeys.eu.pgp.net
  hkp://wwwkeys.us.pgp.net
  ldap://keyserver.pgp.com
}

proc nuevo_toplevel {} {
  return ".toplevel_id[incr ::nuevo_toplevel_id]"
}

namespace eval ::img {
  # Coloco inline un par de imágenes que uso a lo largo del programa:
  image create photo ::img::no -data {
    R0lGODlhEQARAKEDANIGAOJaWPCsq////yH5BAEAAAMALAAAAAARABEAQAI8
    nDKpmyGcgERQPMhoEnMFeSkfEBqgwgFadnrTWLJkug4wZoM03khbJ4uNKDfc
    qMU7qpKtlBApOjl5OUABADs=
  }
  image create photo ::img::yes -data {
    R0lGODlhEgATAKECACPWIMf2yv///////yH5BAEKAAIALAAAAAASABMAAAIz
    lI8YG+kWgGxPyVlPvDRvnAkf0HlcCF0AKqpl9b0aFcNSezpx/Yx5r/oBXaiR
    bHiEJRMFADs=
  }
}

#######################################################################
################################ Clave ################################
#######################################################################

namespace eval ::clave {
  array set this {}
  set img_barra [image create bitmap -data {
    #define barra_width 100
    #define barra_height 3
    static unsigned char barra_bits[] = {
      0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
      0x0f, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x08, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
      0xff, 0xff, 0x0f };
  }]

  proc new {} {
    variable this_id
    return [incr this_id]
  }

  proc actualiza_clave_datos {instancia clave servidor callback fd} {
    variable actualiza_clave_info
    variable fd_asociados
    if {[eof $fd]} {
      catch {close $fd} res
      unset fd_asociados($instancia,$fd)
      {*}$callback "$res\n$actualiza_clave_info($fd)\n"
      unset actualiza_clave_info($fd)
    } else {
      gets $fd linea
      append actualiza_clave_info($fd) $linea
    }
    return
  }

  proc actualiza_clave {instancia clave servidor callback} {
    variable actualiza_clave_info
    variable fd_asociados
    variable after_asociados
    set id [dict get $clave id]
    if {[catch {
      set fd [open [list |gpg --keyserver $servidor --no-auto-check-trustdb --recv-key $id] r]
    } res]} {
      set after_asociados($instancia,$servidor,$id) [after 100 \
	$callback [list "$res\n"] ";" \
	[list unset [namespace current]::after_asociados($instancia,$servidor,$id)]]
      return
    }
    set actualiza_clave_info($fd) ""
    set fd_asociados($instancia,$fd) $fd
    fconfigure $fd -buffering line
    fileevent $fd readable [namespace code \
	[list actualiza_clave_datos $instancia $clave $servidor $callback $fd]]
    return
  }

  proc exporta_clave_datos {instancia clave servidor callback fd} {
    variable exporta_clave_info
    variable fd_asociados
    if {[eof $fd]} {
      catch {close $fd} res
      unset fd_asociados($instancia,$fd)
      {*}$callback "$res\n$exporta_clave_info($fd)\n"
      unset exporta_clave_info($fd)
    } else {
      gets $fd linea
      append exporta_clave_info($fd) $linea
    }
    return
  }

  proc exporta_clave {instancia clave servidor callback} {
    variable exporta_clave_info
    variable fd_asociados
    variable after_asociados
    set id [dict get $clave id]
    if {[catch {
      set fd [open [list |gpg --keyserver $servidor --no-auto-check-trustdb --send-key $id] r]
    } res]} {
      set after_asociados($instancia,$servidor,$id) [after 100 \
	$callback [list "$res\n"] ";" \
	[list unset [namespace current]::after_asociados($instancia,$servidor,$id)]]
      return
    }
    set exporta_clave_info($fd) ""
    set fd_asociados($instancia,$fd) $fd
    fconfigure $fd -buffering line
    fileevent $fd readable [namespace code \
	[list exporta_clave_datos $instancia $clave $servidor $callback $fd]]
    return
  }

  proc cerrar {instance} {
    variable fd_asociados
    variable after_asociados
    variable this
    variable actualiza_clave_info
    variable exporta_clave_info
    foreach {name fd} [array get fd_asociados "$instance,*"] {
      fileevent $fd readable ""
      fconfigure $fd -blocking false
      catch {close $fd}
      unset fd_asociados($instance,$fd)
    }
    foreach {name id} [array get after_asociados "$instance,*"] {
      after cancel $id
      unset after_asociados($name)
    }
    array unset this "$instance,*"
  }

  proc initialize_tasks {instance claves servers} {
    variable this
    set i 0
    foreach server $servers {
      foreach clave $claves {
	set this($instance,tasks,$i) [dict create server $server clave $clave]
	incr i
      }
    }
    set this($instance,nrtasks) $i
  }

  proc get_another_task {instance} {
    variable this
    set nrtasks $this($instance,nrtasks)
    if {$nrtasks == 0} {
      return
    }
    set nr [expr { int($nrtasks * rand()) }]
    set task $this($instance,tasks,$nr)
    incr nrtasks -1
    set this($instance,tasks,$nr) $this($instance,tasks,$nrtasks)
    unset this($instance,tasks,$nrtasks)
    set this($instance,nrtasks) $nrtasks
    return $task
  }

  proc correr_loop {instance evento args} {
    variable this
    switch $evento {
      inicia {
	initialize_tasks $instance {*}$args
	set this($instance,running) 0
	while {$this($instance,running) < 8 && \
	 [llength [set task [get_another_task $instance]]]} {
	  $this($instance,comando) \
		$instance \
		[dict get $task clave] \
		[dict get $task server] \
		[namespace code [list correr_loop $instance ready [dict get $task server]]]
	  incr this($instance,running)
	}
      }
      ready {
	foreach {server texto} $args {}
	variable img_barra
	$this($instance,textwidget) insert end $texto
	set img bar[new]
	$this($instance,textwidget) image create end -image $img_barra -name $img
	$this($instance,textwidget) tag add center $img
	$this($instance,textwidget) insert end "\n"
	$this($instance,progwidget) step
	incr this($instance,running) -1
	if {[llength [set task [get_another_task $instance]]]} {
	  $this($instance,comando) \
		$instance \
		[dict get $task clave] \
		[dict get $task server] \
		[namespace code [list correr_loop $instance ready [dict get $task server]]]
	  incr this($instance,running)
	}
	if {$this($instance,running)==0} {
	  # There are no more servers.
	  $this($instance,textwidget) tag configure grande -font "Sans 14" -justify center
	  $this($instance,textwidget) insert end "Proceso terminado" grande
	  $this($instance,textwidget) yview end
	  return
	}
      }
    }; # acá cierro el switch
  }

  proc crea_interfaz {path claves comando} {
    variable this
    set instance [new]
    set this($instance,path) $path
    set this($instance,comando) $comando
    if {[llength $claves] == 0} {
      tk_messageBox -icon error -message "No se han seleccionado claves." \
	  -title Error: -type ok
      return
    }
    if {$comando!="actualiza_clave" && $comando!="exporta_clave"} {
      error "Comando inválido: $comando"
    }
    toplevel $path
    if {[llength $claves] > 1} {
      wm title $path "[llength $claves] claves"
    } else {
      wm title $path [dict get [lindex $claves 0] uid]
    }
    bind $path <Destroy> [namespace code [list cerrar $instance]]
    pack [::ttk::frame $path.f] -fill both -expand true
    lower [set path $path.f]
    frame $path.m
    set this($instance,textwidget) [text $path.m.t -yscrollcommand [list $path.m.s set]]
    $path.m.t tag configure center -justify center
    ::ttk::scrollbar $path.m.s -orient vertical -command [list $path.m.t yview]
    set this($instance,progwidget) [::ttk::progressbar $path.p -orient horizontal \
	-mode determinate -maximum [expr [llength $::lista_de_servidores] * [llength $claves] + 0.01] -value 0]
    pack $path.m -fill both -expand true
    pack $path.m.t -fill both -expand true -side left
    pack $path.m.s -fill y -expand false -side right
    pack $path.p -fill x -expand false
    correr_loop $instance inicia $claves $::lista_de_servidores
  }
}

########################################################################
############################# Preferencias #############################
########################################################################

namespace eval preferencias {

  array set prefs {}

  proc cargar_servidores {} {
    variable prefs
    set prefs(servidores,lista) {}
    if {[llength [glob -nocomplain ~/.gpgupdater/servidores]]>0} {
      # hay archivo de configuración de servidores
      set fd [open ~/.gpgupdater/servidores r]
      gets $fd prefs(servidores,url)
      set ::lista_de_servidores {}
      while 1 {
	foreach {habilitado servidor} [gets $fd] {}
	if {[eof $fd]} break
	lappend prefs(servidores,lista) $servidor
	set prefs(servidores,habilitado/$servidor) $habilitado
	if {$habilitado} {
	  lappend ::lista_de_servidores $servidor
	}
      }
      close $fd
    } else {
      set prefs(servidores,url) "http://fideo.no-ip.info/cgi-bin/viewcvs.cgi/*checkout*/gpgupdater/servidores"
      foreach servidor $::lista_de_servidores {
	set prefs(servidores,habilitado/$servidor) 1
      }
      set prefs(servidores,lista) $::lista_de_servidores
    }
  }

  proc cargar {} {
    cargar_servidores
  }

  proc aplicar_servidores {nb} {
    variable prefs
    # Aplico a memoria:
    set prefs(servidores,url) [$nb.fs.uf.url get]
    set prefs(servidores,lista) {}
    set ::lista_de_servidores {}
    foreach child [$nb.fs.lf.l children {}] {
      set servidor [$nb.fs.lf.l item $child -text]
      set img [$nb.fs.lf.l item $child -image]
      switch -glob -- $img {
	{*yes} {set habilitado 1}
	{*no} {set habilitado 0}
	default {error "Unknown image in treeview"}
      }
      lappend prefs(servidores,lista) $servidor
      set prefs(servidores,habilitado/$servidor) $habilitado
      if {$habilitado} {
	lappend ::lista_de_servidores $servidor
      }
    }
    # Guardo en disco:
    set fd [open ~/.gpgupdater/servidores w]
    puts $fd $prefs(servidores,url)
    foreach servidor $prefs(servidores,lista) {
      puts $fd [list $prefs(servidores,habilitado/$servidor) $servidor]
    }
    close $fd
  }

  proc aplicar {path} {
    if {[glob -nocomplain ~/.gpgupdater]=={}} {
      file mkdir ~/.gpgupdater
    }
    aplicar_servidores $path.nb
  }

  proc aceptar {path} {
    aplicar $path
    destroy $path
  }

  proc servidores_actualizar_lista_2 {nb token} {
    set srv_count 0
    set srv_new 0
    switch -- [::http::status $token] {
      ok {}
      reset {
	tk_messageBox -icon error -title Error. \
	  -message "Conexión cancelada."
	::http::cleanup $token
	return
      }
      timeout {
	tk_messageBox -icon error -title Error. \
	  -message "Transferencia fallida." \
	  -detail "Tiempo agotado al intentar transferir lista de servidores."
	::http::cleanup $token
	return
      }
      error {
	tk_messageBox -icon error -title Error. \
	  -message "Error al intentar transferir servidores." \
	  -detail [::http::error $token]
	::http::cleanup $token
	return
      }
      default {
	tk_messageBox -icon error -title Error. \
	  -message "Estado desconocido: [::http::status $token]"
	::http::cleanup $token
	return
      }
    }
    if {[lindex [::http::code $token] 1] != 200} {
      tk_messageBox -icon error -title Error. \
	-message "Respuesta inválida del servidor."
	-detail [::http::code $token]
      ::http::cleanup $token
      return
    }
    set servidores {}
    foreach child [$nb.fs.lf.l children {}] {
      lappend servidores [$nb.fs.lf.l item $child -text]
    }
    foreach servidor [split [::http::data $token] "\n"] {
      if {[string equal $servidor ""]} continue; # Línea en blanco
      incr srv_count
      if {[lsearch -exact $servidores $servidor]>=0} \
	continue; # El servidor ya existía.
      incr srv_new
      $nb.fs.lf.l insert {} end -text $servidor -image ::img::yes
    }
    tk_messageBox -icon info -title "Servidores actualizados." \
      -message "Servidores actualizados." \
      -detail "$srv_new servidores nuevos de $srv_count servidores."
    ::http::cleanup $token
  }

  proc servidores_actualizar_lista {nb} {
    if {[catch {
      ::http::geturl [$nb.fs.uf.url get] \
	-command [namespace code [list servidores_actualizar_lista_2 $nb]]
    } res]} {
      tk_messageBox -icon error -title Error. -detail $res \
	-message "Error al establecer comunicación."
    }
  }

  proc (des)habilita_servidor {nb} {
    foreach item [$nb.fs.lf.l selection] {
      set img [$nb.fs.lf.l item $item -image]
      switch -glob -- $img {
	{*yes} {set habilitado 1}
	{*no} {set habilitado 0}
	default {error "Unknown image in treeview"}
      }
      set habilitado [expr !$habilitado]
      $nb.fs.lf.l item $item -image ::img::[expr $habilitado?"yes":"no"]
    }
  }

  proc crea_interfaz_servidores {nb} {
    variable prefs
    ::ttk::frame $nb.fs
    ::ttk::labelframe $nb.fs.lf -text "Lista de servidores:"
    ::ttk::treeview $nb.fs.lf.l -show tree -selectmode browse \
      -yscrollcommand [list $nb.fs.lf.vsb set]
      #-xscrollcommand [list $nb.fs.lf.hsb set]
    foreach servidor $prefs(servidores,lista) {
      set hab $prefs(servidores,habilitado/$servidor)
      $nb.fs.lf.l insert {} end -text $servidor \
	-image ::img::[expr $hab?"yes":"no"]
    }
    bind $nb.fs.lf.l <Double-1> [string map {% %%} \
      [namespace code [list (des)habilita_servidor $nb]] \
    ]
    #::ttk::scrollbar $nb.fs.lf.hsb -orient horizontal -command [list $nb.fs.lf.l xview]
    ::ttk::scrollbar $nb.fs.lf.vsb -orient vertical -command [list $nb.fs.lf.l yview]
    ::ttk::label $nb.fs.lf.info -text "Haga doble click para (des)habilitar servidor"
    ::ttk::frame $nb.fs.uf
    ::ttk::label $nb.fs.uf.l -text "URL:"
    ::ttk::entry $nb.fs.uf.url
    $nb.fs.uf.url insert end $prefs(servidores,url)
    ::ttk::button $nb.fs.uf.actualizar -text "Actualizar lista" \
      -command [namespace code [list servidores_actualizar_lista $nb]]
    pack $nb.fs.lf -fill both -expand true -padx 2 -pady 2
    grid $nb.fs.lf.l -row 0 -column 0 -sticky nsew
    grid $nb.fs.lf.vsb -row 0 -column 1 -sticky nsew
    #grid $nb.fs.lf.hsb -row 1 -column 0 -sticky nsew
    grid $nb.fs.lf.info -row 2 -column 0 -columnspan 2 -sticky nsew
    grid columnconfigure $nb.fs.lf 0 -weight 1
    grid rowconfigure $nb.fs.lf 0 -weight 1
    pack $nb.fs.uf -fill x -expand false -padx 2 -pady 2
    pack $nb.fs.uf.l -fill y -expand false -side left -padx 2 -pady 2
    pack $nb.fs.uf.url -fill both -expand true -side left -padx 2 -pady 2
    pack $nb.fs.uf.actualizar -fill y -expand false -side left -padx 2 -pady 2
    $nb add $nb.fs -text Servidores
  }

  proc crea_interfaz {path} {
    toplevel $path
    wm title $path "Preferencias"
    wm minsize $path 1 1
    grab $path
    ::ttk::notebook $path.nb
    ::ttk::frame $path.f -borderwidth 2 -relief raised
    ::ttk::button $path.f.cancelar -text "Cancelar" -command [namespace code [list destroy $path]]
    ::ttk::button $path.f.aplicar -text "Aplicar" -command [namespace code [list aplicar $path]]
    ::ttk::button $path.f.aceptar -text "Aceptar" -command [namespace code [list aceptar $path]]
    pack $path.nb -fill both -expand true -padx 2 -pady 2
    pack $path.f -fill x -expand false -padx 2 -pady 2
    pack $path.f.cancelar -side right -fill none -expand false -padx 2 -pady 2
    pack $path.f.aplicar -side right -fill none -expand false -padx 2 -pady 2
    pack $path.f.aceptar -side right -fill none -expand false -padx 2 -pady 2
    crea_interfaz_servidores $path.nb
  }
}

########################################################################
########################## Interfaz principal ##########################
########################################################################

proc obtiene_subconjunto_de_claves_seleccionadas {combo lista} {
  # subprocedimiento anónimo que obtiene lista de claves únicas:
  set unique {{claves} {
      set lista {}
      foreach datos $claves {
	set id [dict get $datos id]
	if {![info exists clave($id)]} {
	  set clave($id) 1
	  lappend lista $datos
	}
      }
      return $lista
  }}
  set current [$combo current]
  if {$current < 0} {
    return {}
  } elseif {$current == 0} {
    # Todas las claves:
    return [apply $unique $lista]
  } else {
    # Solo la seleccionada:
    return [list [lindex $lista [expr {$current - 1}]]]
  }
  # Capaz que en un futuro agrego soporte a selección múltiple.
}

proc crea_interfaz_lista {path lista} {
  pack [::ttk::frame $path.f] -fill both -expand true
  lower [set path $path.f]
  ::ttk::label $path.listatext -text "Elija clave:"
  set desclist {"Todas las claves"}
  foreach i $lista {lappend desclist [dict get $i desc]}
  ::ttk::combobox $path.lista -values $desclist -state readonly
  if {[llength $lista]!=0} {$path.lista current 0}
  ::ttk::button $path.actualiza -text "Actualiza clave pública desde servidores" \
    -command [subst -nobackslashes -nocommands {::clave::crea_interfaz [nuevo_toplevel] [::obtiene_subconjunto_de_claves_seleccionadas $path.lista {$lista}] actualiza_clave}]
  ::ttk::button $path.exporta -text "Exporta clave pública hacia servidores" \
    -command [subst -nobackslashes -nocommands {::clave::crea_interfaz [nuevo_toplevel] [::obtiene_subconjunto_de_claves_seleccionadas $path.lista {$lista}] exporta_clave}]
  ::ttk::button $path.prefs -text "Preferencias" \
    -command {::preferencias::crea_interfaz [nuevo_toplevel]}
  foreach {widget   x y xs ys} [list \
    $path.listatext 0 0  1  1 \
    $path.lista     1 0  1  1 \
    $path.actualiza 0 1  2  1 \
    $path.exporta   0 2  2  1 \
  ] {
    grid configure $widget -column $x -row $y -columnspan $xs -rowspan $ys \
	-padx 2 -pady 2 -sticky nsew
  }
  grid configure $path.prefs -column 1 -row 3 -sticky e
  grid rowconfigure $path all -pad 2
  grid columnconfigure $path all -pad 2
  grid columnconfigure $path 1 -weight 1
  grid anchor $path center
}

# devuelve una lista de dicts con {id uid desc}
proc lista_claves {} {
  set fdsecret [open {|gpg --list-secret-keys} r]
  set fdpublic [open {|gpg --list-public-keys} r]
  set fd $fdsecret; # primero parseo fdsecret.
  while true {
    if {$fd==$fdsecret && [eof $fdsecret]} {
      set fd $fdpublic
      catch {close $fdsecret}
    } elseif {$fd==$fdpublic && [eof $fdpublic]} {
      catch {close $fdpublic}
      return [concat [lsort -index 3 $secclaves] [lsort -index 3 $pubclaves]]
    }
    gets $fd linea
    if {$linea=="" && [info exists id] && [info exists uid]} {
      if {$fd==$fdsecret} {
	lappend secclaves [list id $id uid $uid desc "$id - $uid"]
	set clave($uid) 1; # con esto evito repetidos en pubclaves
      } elseif {![info exists clave($uid)]} {
	lappend pubclaves [list id $id uid $uid desc "$id - $uid"]
      }
      unset id
      unset uid
    }
    switch [lindex $linea 0] {
      sec {
	regexp {[0-9A-Z]{8}} $linea id
      }
      pub {
	regexp {[0-9A-Z]{8}} $linea id
      }
      uid {
	if {![info exists uid]} {
	  regexp { +(.*)} $linea linea uid
	}
      }
    }
  }
  # Es un while true, así que nunca va a llegar hasta acá.
}

preferencias::cargar
crea_interfaz_lista "" [lista_claves]
wm resizable . true false
wm minsize . 300 1
