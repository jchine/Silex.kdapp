kite         = KD.getSingleton "kiteController"
{nickname}   = KD.whoami().profile
appStorage = new AppStorage "Silex-installer", "1.0"

class InstallPane extends SilexPane

  constructor:->

    super

    @form = new KDFormViewWithFields
      callback              : @bound "installSilex"
      buttons               :
        install             :
          title             : "Create Silex instance"
          style             : "cupid-green"
          type              : "submit"
          loader            :
            color           : "#444444"
            diameter        : 12
      fields                :
        name                :
          label             : "Name of Silex App:"
          name              : "name"
          placeholder       : "type a name for your app..."
          defaultValue      : "trysilex"
          validate          :
            rules           :
              required      : "yes"
              regExp        : /(^$)|(^[a-z\d]+([_][a-z\d]+)*$)/i
            messages        :
              required      : "a name for your silex app is required!"
          nextElement       :
            timestamp       :
              name          : "timestamp"
              type          : "hidden"
              defaultValue  : Date.now()
        domain              :
          label             : "Domain :"
          name              : "domain"
          itemClass         : KDSelectBox
          defaultValue      : "#{nickname}.kd.io"
        typeinstall         :
          label             : "Type of installation :"
          name              : "typeinstall"
          itemClass         : KDSelectBox
          defaultValue      : "skeleton"
        silexversion        :
          label             : "Silex Version :"
          name              : "silexversion"
          itemClass         : KDSelectBox
          defaultValue      : "1.1"

    @form.on "FormValidationFailed", => @form.buttons["Create Silex instance"].hideLoader()

    vmc = KD.getSingleton 'vmController'

    vmc.fetchVMs (err, vms)=>
      if err then console.log err
      else
        vms.forEach (vm) =>
          vmc.fetchVMDomains vm, (err, domains) =>
            newSelectOptions = []
            usableDomains = [domain for domain in domains when not /^(vm|shared)-[0-9]/.test domain].first
            usableDomains.forEach (domain) =>
              newSelectOptions.push {title : domain, value : domain}

            {domain} = @form.inputs
            domain.setSelectOptions newSelectOptions
        
    newTypeOptions = []
    # Implement later, pip only supports stable version
    #newVersionOptions.push {title : "Latest (git)", value : "git"}
    newTypeOptions.push {title : "Skeleton of Fabien Potencier", value : "skeleton"}
    newTypeOptions.push {title : "Classic", value : "classic"}

    {typeinstall} = @form.inputs
    typeinstall.setSelectOptions newTypeOptions

    newVersionOptions = []
    # Implement later, pip only supports stable version
    #newVersionOptions.push {title : "Latest (git)", value : "git"}
    newVersionOptions.push {title : "1.1", value : "1.1"}

    {silexversion} = @form.inputs
    silexversion.setSelectOptions newVersionOptions

  completeInputs:(fromPath = no)->

    {path, name, pathExtension} = @form.inputs
    if fromPath
      val  = path.getValue()
      slug = KD.utils.slugify val
      path.setValue val.replace('/', '') if /\//.test val
    else
      slug = KD.utils.slugify name.getValue()
      path.setValue slug

    slug += "/" if slug

    pathExtension.inputLabel.updateTitle "/#{slug}"

  checkPath: (name, callback)->
    instancesDir = "silexapp"

    kite.run "[ -d /home/#{nickname}/Web/#{instancesDir}/#{name} ] && echo 'These directories exist'"
    , (err, response)->
      if response
        console.log "You have already a Silex instance with the name \"#{name}\". Please delete it or choose another path"
      callback? err, response

  showInstallFail: ->
    new KDNotificationView
        title     : "Silex instance exists already. Please delete it or choose another name"
        duration  : 3000

  installSilex: =>
    domain = @form.inputs.domain.getValue()
    name = @form.inputs.name.getValue()
    typeinstall = @form.inputs.typeinstall.getValue()
    silexversion = @form.inputs.silexversion.getValue()
    timestamp = parseInt @form.inputs.timestamp.getValue(), 10

    console.log "SILEX INSTALL ", typeinstall
    console.log "SILEX VERSION", silexversion
    @checkPath name, (err, response)=>
      if err # means there is no such folder
        console.log "Starting install with formData", @form

        #If you change it, grep the source file because this variable is used
        instancesDir = "silexapp"
        tmpAppDir = "#{instancesDir}/tmp"

        kite.run "mkdir -p '#{tmpAppDir}'", (err, res)=>
          if err then console.log err
          else
            silexScript = """
                          sudo apt-get install php5-mcrypt
                          curl -sS https://getcomposer.org/installer | php
                          """ 
            if typeinstall == "classic" 
              silexScript = silexScript + """
                          php composer.phar create-project silex/silex #{name} --stability=dev
                          """ 
            else
              silexScript = silexScript + """
                          php composer.phar create-project silexphp/silex-skeleton #{name} --stability=dev
                          """

            silexScript = silexScript + """
                          mv .composer #{name} vendor/ composer.phar Web/
                          sudo chmod -R 777 Web/#{name}/app/storage
                          rm -rf silexapp
                          echo '*** -> Installation successfull, Silex is ready!!!.'
                          """ 

            newFile = FSHelper.createFile
              type   : 'file'
              path   : "#{tmpAppDir}/silexScript.sh"
              vmName : @vmName

            newFile.save silexScript, (err, res)=>
              if err then warn err
              else
                @emit "fs.saveAs.finished", newFile, @

            installCmd = "bash #{tmpAppDir}/silexScript.sh\n"
            formData = {timestamp: timestamp, domain: domain, name: name, typeinstall: typeinstall, silexversion: silexversion}

            modal = new ModalViewWithTerminal
              title   : "Creating Silex Instance: '#{name}'"
              width   : 700
              overlay : no
              terminal:
                height: 500
                command: installCmd
                hidden: no
              content : """
                        <div class='modalformline'>
                          <p>Using Silex <strong>#{silexversion}</strong> in install type <strong>#{typeinstall}</strong></p>
                          <br>
                          <i>note: your sudo password is your koding password. </i>
                        </div>
                        """

            @form.buttons.install.hideLoader()
            appStorage.fetchValue 'blogs', (blogs)->
              blogs or= []
              blogs.push formData
              appStorage.setValue "blogs", blogs

            @emit "SilexInstalled", formData

      else # there is a folder on the same path so fail.
        @form.buttons.install.hideLoader()
        @showInstallFail()

  pistachio:-> "{{> this.form}}"
