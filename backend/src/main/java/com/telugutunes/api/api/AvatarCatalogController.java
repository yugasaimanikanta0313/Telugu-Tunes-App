package com.telugutunes.api.api;
import com.mongodb.client.gridfs.model.GridFSFile;
import com.telugutunes.api.config.AuthenticationFilter;
import com.telugutunes.api.domain.AvatarCatalogDocument;
import com.telugutunes.api.repository.AvatarCatalogRepository;
import com.telugutunes.api.repository.HiddenBundledAvatarRepository;
import com.telugutunes.api.domain.HiddenBundledAvatarDocument;
import com.telugutunes.api.service.AuthService;
import java.io.IOException;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.bson.types.ObjectId;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.gridfs.GridFsTemplate;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
@RestController
@RequestMapping("/api/v1/avatar-catalog")
public class AvatarCatalogController {
  private final AvatarCatalogRepository catalog; private final GridFsTemplate files; private final AuthService auth;
  private final HiddenBundledAvatarRepository hiddenBundled;
  public AvatarCatalogController(AvatarCatalogRepository catalog, GridFsTemplate files, AuthService auth,
      HiddenBundledAvatarRepository hiddenBundled) {
    this.catalog=catalog; this.files=files; this.auth=auth; this.hiddenBundled=hiddenBundled;
  }
  public record AvatarUpdate(String name, Boolean active) {}
  @GetMapping("/public") public List<AvatarCatalogDocument> list() { return catalog.findByActiveTrueOrderByCreatedAtDesc(); }
  @GetMapping("/public/hidden-bundled") public List<String> hiddenBundled() {
    return hiddenBundled.findAll().stream().map(HiddenBundledAvatarDocument::presetId).toList();
  }
  @GetMapping("/public/{id}/model") public ResponseEntity<byte[]> model(@PathVariable String id) throws IOException {
    var avatar=catalog.findById(id).filter(AvatarCatalogDocument::active).orElse(null);
    if (avatar==null || !ObjectId.isValid(avatar.mediaId())) return ResponseEntity.notFound().build();
    GridFSFile file=files.findOne(Query.query(Criteria.where("_id").is(new ObjectId(avatar.mediaId()))));
    if (file==null) return ResponseEntity.notFound().build();
    return ResponseEntity.ok().contentType(MediaType.parseMediaType("model/gltf-binary")).body(files.getResource(file).getInputStream().readAllBytes());
  }
  @PostMapping(consumes=MediaType.MULTIPART_FORM_DATA_VALUE)
  public AvatarCatalogDocument upload(@RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @RequestParam String name, @RequestPart("file") MultipartFile file) throws IOException {
    auth.requireAdministrator(memberId);
    String fileName=file.getOriginalFilename()==null?"avatar.glb":file.getOriginalFilename();
    if(file.isEmpty()||file.getSize()>50_000_000||!fileName.toLowerCase().endsWith(".glb"))
      throw new IllegalArgumentException("Upload one self-contained GLB file up to 50 MB.");
    ObjectId mediaId=files.store(file.getInputStream(),fileName,"model/gltf-binary",Map.of("kind","avatar-catalog","uploadedBy",memberId));
    return catalog.save(new AvatarCatalogDocument(null,name.trim(),mediaId.toHexString(),fileName,true,Instant.now()));
  }
  @PutMapping("/{id}") public AvatarCatalogDocument update(@RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,
      @PathVariable String id,@RequestBody AvatarUpdate update){
    auth.requireAdministrator(memberId); var old=catalog.findById(id).orElseThrow(()->new IllegalArgumentException("Avatar not found."));
    return catalog.save(new AvatarCatalogDocument(old.id(),update.name()==null||update.name().isBlank()?old.name():update.name().trim(),old.mediaId(),old.fileName(),update.active()==null?old.active():update.active(),old.createdAt()));
  }
  @DeleteMapping("/{id}") public void delete(@RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,@PathVariable String id){
    auth.requireAdministrator(memberId); var avatar=catalog.findById(id).orElseThrow(()->new IllegalArgumentException("Avatar not found.")); catalog.delete(avatar);
    if(ObjectId.isValid(avatar.mediaId())) files.delete(Query.query(Criteria.where("_id").is(new ObjectId(avatar.mediaId()))));
  }
  @DeleteMapping("/bundled/{presetId}") public void hideBundled(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,@PathVariable String presetId){
    auth.requireAdministrator(memberId);
    if(!List.of("spiderman","ironman","batman","hulk","doraemon","wonderwoman","pikachu","superman").contains(presetId))
      throw new IllegalArgumentException("Bundled avatar not found.");
    hiddenBundled.save(new HiddenBundledAvatarDocument(presetId));
  }
  @PostMapping("/bundled/{presetId}/restore") public void restoreBundled(
      @RequestAttribute(AuthenticationFilter.MEMBER_ID_ATTRIBUTE) String memberId,@PathVariable String presetId){
    auth.requireAdministrator(memberId); hiddenBundled.deleteById(presetId);
  }
}
