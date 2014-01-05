class DashboardPane extends SilexPane

  constructor:->

    super

    @listController = new KDListViewController
      lastToFirst     : yes
      viewOptions     :
        type          : "silex-blog"
        itemClass     : SilexInstalledAppListItem

    @listWrapper = @listController.getView()

    @notice = new KDCustomHTMLView
      tagName : "p"
      cssClass: "why-u-no"
      partial : "You don't have any Silex app installed."

    @notice.hide()

    @loader = new KDLoaderView
      size          :
        width       : 60
      cssClass      : "loader"
      loaderOptions :
        color       : "#ccc"
        diameter    : 30
        density     : 30
        range       : 0.4
        speed       : 1
        FPS         : 24

    @listController.getListView().on "StartWebapp", (listItemView)=>
      {timestamp, domain, name, typeinstall, silexversion} = listItemView.getData()

      instancesDir = "Web"
      silexDir = "/home/#{nickname}/#{instancesDir}/#{name}/"

      instanceDir = "/home/#{nickname}/#{instancesDir}/#{name}"
      silexCmd = "cd #{silexDir} && php artisan list"

      modal = new ModalViewWithTerminal
        title   : "Silex web-app"
        width   : 700
        overlay : no
        terminal:
          height: 500
          command: silexCmd
          hidden: no
        content : """
                  <div class='modalformline'>
                    <p>Running from <strong>#{silexDir}</strong>.</p>
                    <p>Using Silex <strong>#{silexversion}</strong> in <strong>#{typeinstall}</strong> instalation</p>
                  </div>
                  """
      modal.on "terminal.event", (data)->
        new KDNotificationView
          title: "Opened successfuly"

    @listController.getListView().on "DeleteLinkClicked", (listItemView)=>
      {domain, name} = listItemView.getData()

      instancesDir = "Web"
      message = "<pre>/home/#{nickname}/#{instancesDir}/#{name}</pre>"
      command = "rm -r '/home/#{nickname}/#{instancesDir}/#{name}'"
      warning = """<p class='modalformline' style='color:red'>
                     Warning: This will remove everything under this directory
                     </p>"""

      modal = new KDModalView
        title          : "Are you sure want to delete this Silex app?"
        content        : """
                          <div class='modalformline'>
                            <p>#{message}</p>
                          </div>
                          #{warning}
                         """
        height         : "auto"
        overlay        : yes
        width          : 500
        buttons        :
          Delete       :
            style      : "modal-clean-red"
            loader     :
              color    : "#ffffff"
              diameter : 16
            callback   : =>
              @removeItem listItemView
              KD.getSingleton("kiteController").run command, (err, res)=>
                modal.buttons.Delete.hideLoader()
                modal.destroy()
                if err
                  console.log "Deleting Silex Error", err
                  new KDNotificationView
                    title    : "There was an error, you may need to remove it manually!"
                    duration : 3333
                else
                  new KDNotificationView
                    title    : "Your Silex app: '#{name}' is successfully deleted."
                    duration : 3333

  openInNewTab: (url)->
    link = document.createElement "a"
    link.href = link.target = url
    link.style.display = "none"
    document.body.appendChild link
    link.click()
    link.parentNode.removeChild link
  
  removeItem:(listItemView)->

    blogs = appStorage.getValue "blogs"
    blogToDelete = listItemView.getData()
    blogs.splice blogs.indexOf(blogToDelete), 1
    
    appStorage.setValue "blogs", blogs, =>
      @listController.removeItem listItemView
      appStorage.fetchValue "blogs", (blogs)=>
        blogs?=[]
        @notice.show() if blogs.length is 0

  putNewItem:(formData, resizeSplit = yes)->

    tabs = @getDelegate()
    tabs.showPane @
    @listController.addItem formData
    @notice.hide()
    if resizeSplit
      @utils.wait 1500, -> split.resizePanel 0, 1

  viewAppended:->

    super

    @loader.show()

    appStorage.fetchStorage (storage)=>
      @loader.hide()
      blogs = appStorage.getValue("blogs") or []
      if blogs.length > 0
        blogs.sort (a, b) -> if a.timestamp < b.timestamp then -1 else 1
        blogs.forEach (item)=> @putNewItem item, no
      else
        @notice.show()

  pistachio:->
    """
    {{> @loader}}
    {{> @notice}}
    {{> @listWrapper}}
    """

class SilexInstalledAppListItem extends KDListItemView

  constructor:(options, data)->

    options.type = "silex-blog"

    super options, data

    @WebappButton = new KDButtonView
      cssClass   : "clean-gray test-input"
      title      : "Open Silex"
      callback   : => @getDelegate().emit "StartWebapp", @

    @delete = new KDCustomHTMLView
      tagName   : "a"
      cssClass  : "delete-link"
      click     : => @getDelegate().emit "DeleteLinkClicked", @

  viewAppended:->

    @setTemplate @pistachio()
    @template.update()
    @utils.wait => @setClass "in"

  pistachio:->
    {path, timestamp, domain, name, typeinstall, silexversion} = @getData()
    url = "https://#{domain}/#{name}/public"
    instancesDir = "silexapp"
    {nickname} = KD.whoami().profile
    """
    {{> @delete}}
    <a target='_blank' class='name-link' href='#{url}'> {{#(name)}} </a>
    <div class="instance-block">
        Silex Path: /Users/#{nickname}/Web/{{#(name)}}
        <br>
        Silex Version: {{#(silexversion)}}
        <br>
        Type instalation: {{#(typeinstall)}}
        <br>
        URL: #{nickname}.kd.io/{{#(name)}}/public/ 
        <br>
        {{> @WebappButton}}
    </div>
    <time datetime='#{new Date(timestamp)}'>#{$.timeago new Date(timestamp)}</time>
    """

