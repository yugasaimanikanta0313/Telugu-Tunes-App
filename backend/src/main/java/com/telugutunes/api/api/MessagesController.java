package com.telugutunes.api.api;

import com.mongodb.client.gridfs.model.GridFSFile;
import com.telugutunes.api.config.AuthenticationFilter;
import com.telugutunes.api.domain.ChatMessageDocument;
import com.telugutunes.api.domain.ChatAvatarDocument;
import com.telugutunes.api.domain.AvatarStyle;
import com.telugutunes.api.domain.ChatReadDocument;
import com.telugutunes.api.domain.FriendshipDocument;
import com.telugutunes.api.domain.Member;
import com.telugutunes.api.repository.ChatMessageRepository;
import com.telugutunes.api.repository.ChatAvatarRepository;
import com.telugutunes.api.repository.ChatReadRepository;
import com.telugutunes.api.repository.FriendshipRepository;
import com.telugutunes.api.repository.MemberRepository;
import java.io.IOException;
import java.time.Instant;
import java.util.Comparator;
import java.util.Collections;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.bson.types.ObjectId;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.gridfs.GridFsTemplate;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1/messages")
public class MessagesController {
  private final MemberRepository members;
  private final FriendshipRepository friendships;
  private final ChatMessageRepository messages;
  private final ChatAvatarRepository avatars;
  private final ChatReadRepository reads;
  private final GridFsTemplate files;

  public MessagesController(MemberRepository members, FriendshipRepository friendships,
      ChatMessageRepository messages, ChatAvatarRepository avatars,
      ChatReadRepository reads, GridFsTemplate files) {
    this.members = members;
    this.friendships = friendships;
    this.messages = messages;
    this.avatars = avatars;
    this.reads = reads;
    this.files = files;
  }

  public record Person(String id, String name, String email, String avatarId,
      String avatarEmoji, AvatarStyle avatarStyle, String snapAvatarUrl) {}
  public record FriendView(String id, String status, boolean incoming, Person person,
      ChatMessageDocument lastMessage, long unreadCount) {}
  public record FriendRequest(String email) {}
  public record SendMessage(String clientId, String kind, String text,
      String mediaId, String fileName) {}
  public record AvatarChoice(String emoji) {}
  public record SnapAvatarChoice(String avatarUrl) {}

  @GetMapping("/friends")
  public List<FriendView> friends(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String self) {
    return friendships.findByRequesterIdOrRecipientId(self, self).stream()
        .sorted(Comparator.comparing(FriendshipDocument::createdAt).reversed())
        .map(friend -> {
          boolean incoming = friend.recipientId().equals(self);
          String peerId = incoming ? friend.requesterId() : friend.recipientId();
          Member peer = members.findById(peerId).orElse(null);
          if (peer == null) return null;
          if (!"accepted".equals(friend.status()))
            return new FriendView(friend.id(), friend.status(), incoming, person(peer), null, 0);
          String pair = conversationId(self, peerId);
          Instant cutoff = Instant.now().minusSeconds(86_400);
          var last = messages.findTopByConversationIdAndCreatedAtAfterOrderByCreatedAtDesc(pair, cutoff)
              .orElse(null);
          Instant since = reads.findById(pair + ":" + self)
              .map(ChatReadDocument::lastReadAt).filter(value -> value.isAfter(cutoff))
              .orElse(cutoff);
          long unread = messages.countByConversationIdAndSenderIdAndCreatedAtAfter(pair, peerId, since);
          return new FriendView(friend.id(), friend.status(), incoming, person(peer), last, unread);
        }).filter(view -> view != null).toList();
  }

  @PostMapping("/friends")
  public FriendView requestFriend(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String self,
      @RequestBody FriendRequest request) {
    String email = request.email() == null ? "" : request.email().trim();
    if (!email.toLowerCase().endsWith("@gmail.com"))
      throw new IllegalArgumentException("Enter your friend's Gmail address.");
    Member peer = members.findByEmailIgnoreCase(email)
        .filter(Member::active)
        .orElseThrow(() -> new IllegalArgumentException("No Telugu Tunes account has that Gmail address."));
    if (peer.id().equals(self)) throw new IllegalArgumentException("You cannot add yourself.");
    var existing = friendship(self, peer.id());
    if (existing != null) throw new IllegalArgumentException("A friend request already exists.");
    var saved = friendships.save(new FriendshipDocument(conversationId(self, peer.id()),
        self, peer.id(), "pending", Instant.now()));
    return new FriendView(saved.id(), saved.status(), false,
        person(peer), null, 0);
  }

  @PostMapping("/friends/{requestId}/accept")
  public FriendView accept(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String self,
      @PathVariable String requestId) {
    var request = friendships.findById(requestId)
        .orElseThrow(() -> new IllegalArgumentException("Friend request not found."));
    if (!request.recipientId().equals(self) || !request.status().equals("pending"))
      throw new IllegalArgumentException("Only the recipient can accept this request.");
    var saved = friendships.save(new FriendshipDocument(request.id(), request.requesterId(),
        request.recipientId(), "accepted", request.createdAt()));
    Member peer = members.findById(saved.requesterId()).orElseThrow();
    return new FriendView(saved.id(), saved.status(), true,
        person(peer), null, 0);
  }

  @PostMapping(value = "/avatar", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
  public Person avatar(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String self,
      @RequestPart("file") MultipartFile file) throws IOException {
    if (file.isEmpty() || file.getSize() > 5_000_000
        || file.getContentType() == null || !file.getContentType().startsWith("image/"))
      throw new IllegalArgumentException("Choose an image up to 5 MB.");
    ObjectId id = files.store(file.getInputStream(), "avatar", file.getContentType(),
        Map.of("ownerId", self));
    avatars.save(new ChatAvatarDocument(self, id.toHexString(), "", null, ""));
    return person(members.findById(self).orElseThrow());
  }

  @PostMapping("/avatar/emoji")
  public Person avatarEmoji(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String self,
      @RequestBody AvatarChoice choice) {
    if (choice.emoji() == null || !List.of("😀", "😎", "🥳", "🐯", "🦊", "🐼", "👩", "👨", "🧑", "🎵").contains(choice.emoji()))
      throw new IllegalArgumentException("Choose an avatar from the list.");
    avatars.save(new ChatAvatarDocument(self, "", choice.emoji(), null, ""));
    return person(members.findById(self).orElseThrow());
  }

  @PostMapping("/avatar/style")
  public Person avatarStyle(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String self,
      @RequestBody AvatarStyle style) {
    if (style == null
        || (style.presentation() != null
            && !List.of("male", "female", "neutral").contains(style.presentation()))
        || !List.of("light", "tan", "brown", "deep").contains(style.skin())
        || !List.of("short", "curly", "long", "bun", "spiky").contains(style.hair())
        || !List.of("black", "brown", "blonde", "purple", "red").contains(style.hairColor())
        || !List.of("round", "sleepy", "wide", "wink").contains(style.eyes())
        || !List.of("hoodie", "jacket", "dress", "tee").contains(style.outfit())
        || !List.of("violet", "blue", "coral", "green", "yellow").contains(style.outfitColor())
        || !List.of("jeans", "shorts", "skirt").contains(style.bottoms())
        || !List.of("blue", "black", "beige", "purple").contains(style.bottomColor())
        || !List.of("wave", "stand", "dance", "hands-up").contains(style.pose())
        || Math.abs(style.leftArm()) > 90 || Math.abs(style.rightArm()) > 90
        || Math.abs(style.leftLeg()) > 90 || Math.abs(style.rightLeg()) > 90)
      throw new IllegalArgumentException("Choose an avatar option from each list.");
    avatars.save(new ChatAvatarDocument(self, "", "", style, ""));
    return person(members.findById(self).orElseThrow());
  }

  @PostMapping("/avatar/snap")
  public Person snapAvatar(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String self,
      @RequestBody SnapAvatarChoice choice) {
    String url = choice.avatarUrl() == null ? "" : choice.avatarUrl();
    java.net.URI uri;
    try { uri = java.net.URI.create(url); }
    catch (IllegalArgumentException error) { throw new IllegalArgumentException("Invalid Bitmoji avatar URL."); }
    String host = uri.getHost() == null ? "" : uri.getHost().toLowerCase(java.util.Locale.ROOT);
    if (!"https".equalsIgnoreCase(uri.getScheme()) || url.length() > 2048
        || !(host.equals("sdk.bitmoji.com") || host.endsWith(".bitmoji.com")
            || host.endsWith(".sc-cdn.net") || host.endsWith(".snapchat.com")))
      throw new IllegalArgumentException("Invalid Bitmoji avatar URL.");
    avatars.save(new ChatAvatarDocument(self, "", "", null, url));
    return person(members.findById(self).orElseThrow());
  }

  @GetMapping("/avatar/me")
  public Person myAvatar(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String self) {
    return person(members.findById(self).orElseThrow());
  }

  @GetMapping("/{peerId}")
  public List<ChatMessageDocument> conversation(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String self,
      @PathVariable String peerId) {
    requireFriends(self, peerId);
    var result = new ArrayList<>(messages.findTop100ByConversationIdAndCreatedAtAfterOrderByCreatedAtDesc(
        conversationId(self, peerId), Instant.now().minusSeconds(86_400)));
    Collections.reverse(result);
    return result;
  }

  @PostMapping("/{peerId}/read")
  public void markRead(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String self,
      @PathVariable String peerId) {
    requireFriends(self, peerId);
    reads.save(new ChatReadDocument(conversationId(self, peerId) + ":" + self, Instant.now()));
  }

  @PostMapping("/{peerId}")
  public ChatMessageDocument send(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String self,
      @PathVariable String peerId, @RequestBody SendMessage request) {
    requireFriends(self, peerId);
    String kind = request.kind() == null ? "text" : request.kind();
    if (!List.of("text", "sticker", "file", "image", "video", "audio").contains(kind))
      throw new IllegalArgumentException("Unsupported message type.");
    String text = request.text() == null ? "" : request.text().trim();
    String mediaId = request.mediaId() == null ? "" : request.mediaId();
    if (text.isEmpty() && mediaId.isEmpty()) throw new IllegalArgumentException("Message is empty.");
    if (!mediaId.isEmpty()) {
      if (!ObjectId.isValid(mediaId)) throw new IllegalArgumentException("Attachment not found.");
      GridFSFile attachment = files.findOne(Query.query(Criteria.where("_id").is(new ObjectId(mediaId))));
      if (attachment == null || attachment.getMetadata() == null
          || !self.equals(attachment.getMetadata().getString("ownerId"))
          || attachment.getUploadDate().toInstant().isBefore(Instant.now().minusSeconds(86_400)))
        throw new IllegalArgumentException("Attachment not found.");
    }
    String pair = conversationId(self, peerId);
    String clientId = request.clientId() == null ? "" : request.clientId();
    if (!clientId.isEmpty()) {
      var existing = messages.findByConversationIdAndSenderIdAndClientId(pair, self, clientId);
      if (existing.isPresent() && existing.get().createdAt().isAfter(Instant.now().minusSeconds(86_400)))
        return existing.get();
    }
    return messages.save(new ChatMessageDocument(null, pair, self, clientId, kind,
        text, mediaId, request.fileName() == null ? "" : request.fileName(), Instant.now()));
  }

  @PostMapping(value = "/media", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
  public Map<String, String> upload(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String self,
      @RequestPart("file") MultipartFile file) throws IOException {
    if (file.isEmpty() || file.getSize() > 50_000_000)
      throw new IllegalArgumentException("Choose a file up to 50 MB.");
    String name = file.getOriginalFilename() == null ? "attachment" : file.getOriginalFilename();
    String type = file.getContentType() == null ? "application/octet-stream" : file.getContentType();
    ObjectId id = files.store(file.getInputStream(), name, type,
        Map.of("ownerId", self, "kind", "chat"));
    return Map.of("id", id.toHexString(), "name", name, "contentType", type);
  }

  @GetMapping("/media/{id}")
  public ResponseEntity<byte[]> media(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String self,
      @PathVariable String id) throws IOException {
    if (!ObjectId.isValid(id)) return ResponseEntity.notFound().build();
    GridFSFile file = files.findOne(Query.query(Criteria.where("_id").is(new ObjectId(id))));
    if (file == null) return ResponseEntity.notFound().build();
    String owner = file.getMetadata() == null ? "" : file.getMetadata().getString("ownerId");
    boolean avatarAllowed = avatars.findById(owner)
        .map(avatar -> id.equals(avatar.mediaId())
            && (owner.equals(self) || acceptedFriend(self, owner)))
        .orElse(false);
    if (!avatarAllowed &&
        file.getUploadDate().toInstant().isBefore(Instant.now().minusSeconds(86_400)))
      return ResponseEntity.notFound().build();
    boolean allowed = owner.equals(self) || avatarAllowed || messages.findByMediaId(id).stream()
        .anyMatch(message -> {
          String[] pair = message.conversationId().split(":", 2);
          return pair.length == 2 && (pair[0].equals(self) || pair[1].equals(self))
              && message.createdAt().isAfter(Instant.now().minusSeconds(86_400))
              && acceptedFriend(pair[0], pair[1]);
        });
    if (!allowed) return ResponseEntity.notFound().build();
    var resource = files.getResource(file);
    String safeName = file.getFilename().replaceAll("[^A-Za-z0-9._-]", "_");
    return ResponseEntity.ok()
        .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + safeName + "\"")
        .contentType(MediaType.parseMediaType(file.getMetadata() == null || file.getMetadata().getString("_contentType") == null
            ? "application/octet-stream" : file.getMetadata().getString("_contentType")))
        .body(resource.getInputStream().readAllBytes());
  }

  private FriendshipDocument friendship(String a, String b) {
    return friendships.findByRequesterIdOrRecipientId(a, a).stream()
        .filter(friend -> (friend.requesterId().equals(a) && friend.recipientId().equals(b))
            || (friend.requesterId().equals(b) && friend.recipientId().equals(a)))
        .findFirst().orElse(null);
  }

  private void requireFriends(String a, String b) {
    if (!acceptedFriend(a, b))
      throw new IllegalArgumentException("Accept the friend request before chatting.");
  }

  private boolean acceptedFriend(String a, String b) {
    var friend = friendship(a, b);
    return friend != null && friend.status().equals("accepted");
  }

  private Person person(Member member) {
    var avatar = avatars.findById(member.id()).orElse(new ChatAvatarDocument(member.id(), "", "", null, ""));
    return new Person(member.id(), member.displayName(), member.email(),
        avatar.mediaId() == null ? "" : avatar.mediaId(),
        avatar.emoji() == null ? "" : avatar.emoji(), avatar.style(),
        avatar.snapAvatarUrl() == null ? "" : avatar.snapAvatarUrl());
  }

  private String conversationId(String a, String b) {
    return a.compareTo(b) < 0 ? a + ":" + b : b + ":" + a;
  }
}
