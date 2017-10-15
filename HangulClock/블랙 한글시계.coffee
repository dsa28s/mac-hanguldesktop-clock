style: """
  top: 50%;
  left: 50%;
  font-family: 'Apple SD Gothic Neo', sans-serif
  color: rgba(0, 0, 0, .20)
  font-weight: 300
  font-size: 50px
  line-height: 1.1em
  transform: translate(-50%, -50%)
  
  .active
    color: rgba(0, 0, 0, 1)
    text-shadow: 1px 1px 0px rgba(105, 105, 105, .4)

  .fighting
    color: black
    font-family: 'Apple SD Gothic Neo', sans-serif
    font-weight: 100
    display: table-cell;
    vertical-align: middle;
    text-align: center;

  .bottom
    padding-top: 30px;

  .content-left
    float: left;
    margin-left: -200px;

  .content-right
    float: right;
    margin-right: -80px;

  .message-right
    float: left;
    width: 400px;
    word-wrap: break-word;
    margin-right: -200px;
    padding-left: 60px;
    margin-top: 125px;
    white-space: pre;

  .message-left
    float: left;
    width: 400px;
    margin-left: -90px;
    padding-right: 80px;
    margin-top: 130px;
    word-wrap: break-word;
    white-space: pre;

  .SangsClock {
    width: 330px
    padding: 50px
    margin: auto
  }

  .SangsClock {position:relative}
  .SangsClock:before, .SangsClock:after, .SangsClock>:first-child:before, .SangsClock>:first-child:after {
      position:absolute; content:' '
      width:60px; height: 60px
      border-color: black
      border-style:solid
  }
  .SangsClock:before {top:0;left:0;border-width: 10px 0 0 10px}
  .SangsClock:after {top:0;right:0;border-width: 0px 0px 0 0}
  .SangsClock>:first-child:before {bottom:0;right:0;border-width: 0 10px 10px 0}
  .SangsClock>:first-child:after {bottom:0;left:0;border-width: 0 0 0px 0px}

"""
command: "id -F && curl -sD -o /dev/null 'https://hangulclock.sangs.me/154/'"

refreshFrequency: 10000 # (1000 * n) seconds


render: (o) -> """
  <p id="message_top" class="fighting">#{o}</p><br />
  <div id="content">
    <div class='SangsClock'>
        <span id="한">한 </span><span id="두">두 </span><span id="세">세 </span><span id="네">네 </span><span id="다">다 </span><span id="섯">섯 </span><br/>
        <span id="여">여 </span><span id="섯2">섯 </span><span id="일">일 </span><span id="곱">곱 </span><span id="여2">여 </span><span id="덟">덟 </span><br/>
        <span id="아">아 </span><span id="홉">홉 </span><span id="열">열 </span><span id="한2">한 </span><span id="두2">두 </span><span id="시">시 </span><br/>
        <span id="자">자 </span><span id="이">이 </span><span id="삼">삼 </span><span id="사">사 </span><span id="오">오 </span><span id="십">십 </span><br />
        <span id="정">정 </span><span id="일2">일 </span><span id="이2">이 </span><span id="삼2">삼 </span><span id="사2">사 </span><span id="육">육 </span><br />
        <span id="오2">오 </span><span id="오3">오 </span><span id="칠">칠 </span><span id="팔">팔 </span><span id="구">구 </span><span id="분">분 </span><br/>
    </div>
  </div>
  <p id="message_bottom" class="fighting bottom">#{o}</p><br />
  <div id="log" class="active">

  </div>
"""


update: (output, dom) ->
  hours = [["열", "두2"], ["한"], ["두"], ["세"], ["네"], ["다", "섯"], ["여", "섯2"], ["일", "곱"], ["여2", "덟"], ["아", "홉"], ["열"],
    ["열", "한2"], ["열", "두2"]]
  minutes = [[""], ["일2"], ["이2"], ["삼2"], ["사2"], ["오3"], ["육"], ["칠"], ["팔"], ["구"], ["십"], ["십", "일2"], ["십", "이2"],
    ["십", "삼2"], ["십", "사2"], ["십", "오3"], ["십", "육"], ["십", "칠"], ["십", "팔"], ["십", "구"], ["이", "십"], ["이", "십", "일2"],
    ["이", "십", "이2"], ["이", "십", "삼2"], ["이", "십", "사2"], ["이", "십", "오3"], ["이", "십", "육"], ["이", "십", "칠"],
    ["이", "십", "팔"], ["이", "십", "구"], ["삼", "십"], ["삼", "십", "일2"], ["삼", "십", "이2"], ["삼", "십", "삼2"], ["삼", "십", "사2"],
    ["삼", "십", "오3"], ["삼", "십", "육"], ["삼", "십", "칠"], ["삼", "십", "팔"], ["삼", "십", "구"], ["사", "십"], ["사", "십", "일2"],
    ["사", "십", "이2"], ["사", "십", "삼2"], ["사", "십", "사2"], ["사", "십", "오3"], ["사", "십", "육"], ["사", "십", "칠"],
    ["사", "십", "팔"], ["사", "십", "구"], ["오", "십"], ["오", "십", "일2"], ["오", "십", "이2"], ["오", "십", "삼2"], ["오", "십", "사2"],
    ["오", "십", "오3"], ["오", "십", "육"], ["오", "십", "칠"], ["오", "십", "팔"], ["오", "십", "구"]]
  noons = [["자", "정"], ["정", "오1"]]

  ligthOffAll = () -> $(dom).find(".active").removeClass("active")
  lightOn = (str) -> $(dom).find("##{str}").addClass("active")
  log = (str) -> $(dom).find("#log").html(str)
  timeOn = (ar) -> lightOn typo for typo in ar
  getParameters = () ->
    query = window.location.search.substring(1)
    raw_vars = query.split("&")
    params = {}
    for v in raw_vars
      [key, val] = v.split("=")
      params[key] = decodeURIComponent(val)
    params

  ligthOffAll()

  date = new Date()
  minute = date.getMinutes()
  hour = date.getHours()

  if(getParameters().messagePosition == "1")
    $(dom).find("#message_top").css("display", "block")
    $(dom).find("#message_bottom").css("display", "none")
  else if(getParameters().messagePosition == "2")
    $(dom).find("#message_top").css("display", "none")
    $(dom).find("#message_bottom").css("display", "block")
  else if(getParameters().messagePosition == "3")
    $(dom).find("#message_top").css("display", "none")
    $(dom).find("#message_bottom").css("display", "block")
    $(dom).find("#message_bottom").addClass("message-right")
    $(dom).find("#content").addClass("content-left")
  else if(getParameters().messagePosition == "4")
    $(dom).find("#message_top").css("display", "none")
    $(dom).find("#message_bottom").css("display", "block")
    $(dom).find("#message_bottom").addClass("message-left")
    $(dom).find("#content").addClass("content-right")
  else

  if(getParameters().customMessage == "default" || getParameters().customMessage == "" || getParameters().customMessage == undefined)
    $(dom).find("#message_top").html(output)
    $(dom).find("#message_bottom").html(output)
  else
    $(dom).find("#message_top").html(decodeURIComponent(getParameters().customMessage).replace /[+]/g, " ")
    $(dom).find("#message_bottom").html(decodeURIComponent(getParameters().customMessage).replace /[+]/g, " ")

  if(getParameters().messageDisabled == "1")
    $(dom).find("#message_top").css("display", "none")
    $(dom).find("#message_bottom").css("display", "none")

  if(getParameters().zoom == "1")
    document.body.style.zoom = 0.5;
  else if(getParameters().zoom == "2")
    document.body.style.zoom = 0.75;
  else
    document.body.style.zoom = 1;

  if (hour is 0 or hour is 12) and minute is 0
    lightOn h_typo for h_typo in noons[Math.floor(hour / 12)]
  else
    h_idx = if hour > 12 then hour % 12 else hour
    timeOn(hours[h_idx])
    lightOn("시")

    m_idx = Math.floor(minute)
    if m_idx isnt 0
      timeOn(minutes[m_idx])
      lightOn("분")


